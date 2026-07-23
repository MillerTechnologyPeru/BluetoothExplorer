//
//  PluginManager.swift
//  BluetoothExplorerPluginEngine
//
//  Owns plugin discovery, enable/disable state, and the current routing registry. UI observes
//  `plugins`; the Store reads `registry`.
//
//  All parsing is done by WASM plugins — there are no built-in native decoders. Bundled plugins are
//  loaded read-only from the app bundle; user-imported plugins live in the app's Documents directory
//  and can be deleted.
//

import Foundation
import Observation
import BluetoothExplorerPluginEngine

@MainActor
@Observable
public final class PluginManager {

    /// Where a plugin came from.
    public enum Source: Equatable, Sendable {
        /// Shipped inside the app bundle. Read-only: can be enabled or disabled, not deleted.
        case bundled
        /// Imported by the user into Documents. Can be enabled, disabled, or deleted.
        case imported
    }

    /// UI-facing state for one plugin.
    public struct PluginState: Identifiable, Equatable, Sendable {
        public let id: PluginID
        public let name: String
        public let version: String?
        public let source: Source
        public var isEnabled: Bool
        public var loadError: String?

        /// Only user-imported plugins can be removed; bundled ones live in the read-only app bundle.
        public var isRemovable: Bool { source == .imported }
    }

    public private(set) var plugins: [PluginState] = []
    public private(set) var registry: ParserRegistry

    private var wasmPlugins: [PluginID: WasmParserPlugin] = [:]
    private var order: [PluginID] = []
    private var enabled: [PluginID: Bool] = [:]
    private var sources: [PluginID: Source] = [:]
    private var loadErrors: [PluginID: String] = [:]
    private var displayNames: [PluginID: String] = [:]
    private var versions: [PluginID: String] = [:]

    public init() {
        self.registry = ParserRegistry(plugins: [])
    }

    // MARK: Loading

    /// Where imported plugins live on disk, once `loadInstalledPlugins()` has run.
    public private(set) var directory: PluginDirectory?

    /// Load bundled plugins from the app bundle and imported plugins from Documents.
    ///
    /// Bundled plugins are referenced directly from `Bundle.module` — they are not copied anywhere.
    /// Only user-imported plugins are stored on disk, under `Documents/Plugins`.
    public func loadInstalledPlugins() {
        loadBundledPlugins(from: PluginEngineResources.bundle)
        if let directory = try? PluginDirectory.default() {
            self.directory = directory
            loadImportedPlugins(from: directory)
        }
        rebuild()
    }

    /// Scan a bundle's `Plugins/` directory for `*.bleplugin.json` manifests and load each.
    public func loadBundledPlugins(from bundle: Bundle) {
        let result = PluginLoader.loadBundled(from: bundle)
        for loaded in result.loaded {
            register(loaded.plugin, manifest: loaded.manifest, source: .bundled)
        }
        for failure in result.failures {
            recordFailure(failure, source: .bundled)
        }
        rebuild()
    }

    private func loadImportedPlugins(from directory: PluginDirectory) {
        for manifestURL in directory.installedManifestURLs() {
            do {
                let loaded = try PluginLoader.load(manifestURL: manifestURL, verifyHash: true)
                register(loaded.plugin, manifest: loaded.manifest, source: .imported)
            } catch let failure as PluginLoadFailure {
                recordFailure(failure, source: .imported)
            } catch {
                recordFailure(PluginLoadFailure(manifestName: manifestURL.lastPathComponent,
                                                underlying: nil, message: "\(error)"), source: .imported)
            }
        }
    }

    // MARK: Importing

    /// Why an import failed, in a form the UI can show directly.
    public struct ImportError: Error, Sendable, CustomStringConvertible {
        public let message: String
        public var description: String { message }
    }

    /// Import a plugin the user picked. The manifest and its module are validated, then copied
    /// into the plugin directory and loaded.
    @discardableResult
    public func importPlugin(manifestURL: URL) -> Result<PluginID, ImportError> {
        guard let directory else {
            return .failure(ImportError(message: "Plugin storage is unavailable."))
        }
        #if canImport(Darwin)
        // Files handed over by the document picker live outside the sandbox until claimed.
        let scoped = manifestURL.startAccessingSecurityScopedResource()
        defer { if scoped { manifestURL.stopAccessingSecurityScopedResource() } }
        #endif
        do {
            let manifest = try directory.importPlugin(manifestURL: manifestURL)
            let installed = directory.url
                .appendingPathComponent(PluginDirectory.folderName(for: manifest.identifier), isDirectory: true)
                .appendingPathComponent(manifestURL.lastPathComponent)
            let loaded = try PluginLoader.load(manifestURL: installed, verifyHash: true)
            register(loaded.plugin, manifest: loaded.manifest, source: .imported)
            rebuild()
            return .success(loaded.plugin.id)
        } catch let failure as PluginLoadFailure {
            return .failure(ImportError(message: failure.message))
        } catch {
            return .failure(ImportError(message: "\(error)"))
        }
    }

    private func recordFailure(_ failure: PluginLoadFailure, source: Source) {
        let syntheticID = PluginID(failure.manifestName)
        if order.contains(syntheticID) == false { order.append(syntheticID) }
        sources[syntheticID] = source
        enabled[syntheticID] = false
        displayNames[syntheticID] = failure.manifestName
        loadErrors[syntheticID] = failure.message
    }

    private func register(_ plugin: WasmParserPlugin, manifest: PluginManifest, source: Source) {
        let id = plugin.id
        wasmPlugins[id] = plugin
        if order.contains(id) == false { order.append(id) }
        if enabled[id] == nil { enabled[id] = Self.storedEnabled(id) }
        sources[id] = source
        displayNames[id] = manifest.name
        versions[id] = manifest.version
        loadErrors[id] = nil
    }

    // MARK: Enable / disable / delete

    public func setEnabled(_ isEnabled: Bool, id: PluginID) {
        enabled[id] = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey(id))
        rebuild()
    }

    /// Delete an imported plugin, removing it from the registry and from the Documents directory.
    ///
    /// Bundled plugins cannot be deleted — they live in the read-only app bundle — so this is a
    /// no-op for them. Use `setEnabled(false:)` to turn a bundled plugin off instead.
    public func removePlugin(id: PluginID) {
        guard sources[id] == .imported else { return }
        if let directory {
            try? directory.remove(identifier: id.rawValue)
        }
        wasmPlugins[id] = nil
        order.removeAll { $0 == id }
        enabled[id] = nil
        UserDefaults.standard.removeObject(forKey: Self.enabledKey(id))
        sources[id] = nil
        displayNames[id] = nil
        versions[id] = nil
        loadErrors[id] = nil
        rebuild()
    }

    private static func enabledKey(_ id: PluginID) -> String {
        "plugin.enabled." + id.rawValue
    }

    /// Persisted enable state, defaulting to on for a plugin seen for the first time.
    private static func storedEnabled(_ id: PluginID) -> Bool {
        UserDefaults.standard.object(forKey: enabledKey(id)) as? Bool ?? true
    }

    // MARK: Registry construction

    private func rebuild() {
        var activePlugins = [any ParserPlugin]()
        for id in order {
            guard enabled[id] == true, let plugin = wasmPlugins[id] else { continue }
            activePlugins.append(plugin)
        }
        registry = ParserRegistry(plugins: activePlugins)

        plugins = order.map { id in
            PluginState(
                id: id,
                name: displayNames[id] ?? id.rawValue,
                version: versions[id],
                source: sources[id] ?? .imported,
                isEnabled: enabled[id] ?? false,
                loadError: loadErrors[id]
            )
        }
    }
}
