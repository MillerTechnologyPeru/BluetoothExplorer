//
//  PluginManager.swift
//  BluetoothExplorerPluginEngine
//
//  Owns plugin discovery, enable/disable state, and the current routing registry. UI observes
//  `plugins`; the Store reads `registry`.
//

import Foundation
import Observation
import SkipFuse
import BluetoothExplorerPluginEngine

@MainActor
@Observable
public final class PluginManager {

    /// Where a plugin came from.
    public enum Source: Equatable, Sendable {
        case native
        case bundled
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
    }

    public private(set) var plugins: [PluginState] = []
    public private(set) var registry: ParserRegistry

    private let nativeParsers: [any ParserPlugin]
    private var wasmPlugins: [PluginID: WasmParserPlugin] = [:]
    private var order: [PluginID] = []
    private var enabled: [PluginID: Bool] = [:]
    private var sources: [PluginID: Source] = [:]
    private var loadErrors: [PluginID: String] = [:]
    private var displayNames: [PluginID: String] = [:]
    private var versions: [PluginID: String] = [:]

    public static var defaultNativeParsers: [any ParserPlugin] {
        [NativeIBeaconParser(), NativeWellKnownCharacteristicParser()]
    }

    public init(nativeParsers: [any ParserPlugin] = PluginManager.defaultNativeParsers) {
        self.nativeParsers = nativeParsers
        self.registry = ParserRegistry(plugins: nativeParsers)
        for parser in nativeParsers {
            order.append(parser.id)
            enabled[parser.id] = true
            sources[parser.id] = .native
            displayNames[parser.id] = parser.name
        }
        rebuild()
    }

    // MARK: Loading

    /// Where installed plugins live on disk, once `loadInstalledPlugins()` has run.
    public private(set) var directory: PluginDirectory?

    /// Install bundled plugins into Documents on first launch, then load everything from there.
    ///
    /// This is the normal startup path: bundled and imported plugins end up in the same directory,
    /// so there is a single load path and the user can see and manage every plugin in one place.
    public func loadInstalledPlugins() {
        do {
            let directory = try PluginDirectory.default()
            self.directory = directory
            let freshlyInstalled = Set(try directory.installBundledPlugins(from: PluginEngineResources.bundle))
            load(from: directory, bundledIdentifiers: freshlyInstalled)
        } catch {
            // Falling back to the read-only bundle keeps parsing working even if Documents is
            // unavailable; the user just cannot manage plugins this session.
            loadBundledPlugins(from: PluginEngineResources.bundle)
        }
    }

    private func load(from directory: PluginDirectory, bundledIdentifiers: Set<String>) {
        for manifestURL in directory.installedManifestURLs() {
            do {
                let loaded = try PluginLoader.load(manifestURL: manifestURL, verifyHash: true)
                // Anything installed from the app bundle is "bundled", whether it landed this
                // launch or a previous one; the install record is the source of truth.
                let source: Source = bundledIdentifiers.contains(loaded.manifest.identifier)
                    || bundledManifestIdentifiers.contains(loaded.manifest.identifier)
                    ? .bundled : .imported
                register(loaded.plugin, manifest: loaded.manifest, source: source)
            } catch let failure as PluginLoadFailure {
                recordFailure(failure, source: .imported)
            } catch {
                recordFailure(PluginLoadFailure(manifestName: manifestURL.lastPathComponent,
                                                underlying: nil, message: "\(error)"), source: .imported)
            }
        }
        rebuild()
    }

    /// Identifiers shipped inside the app bundle, used to label a plugin's origin in the UI.
    private var bundledManifestIdentifiers: Set<String> {
        let urls = PluginEngineResources.bundle.urls(
            forResourcesWithExtension: "json", subdirectory: "Plugins") ?? []
        var identifiers = Set<String>()
        for url in urls.map({ $0 as URL })
        where url.lastPathComponent.hasSuffix(PluginDirectory.manifestSuffix) {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data)
            else { continue }
            identifiers.insert(manifest.identifier)
        }
        return identifiers
    }

    /// Scan a bundle's `Plugins/` directory for `*.bleplugin.json` manifests and load each.
    public func loadBundledPlugins(from bundle: Bundle) {
        let result = PluginLoader.loadBundled(from: bundle)
        for loaded in result.loaded {
            register(loaded.plugin, manifest: loaded.manifest, source: .bundled)
        }
        for failure in result.failures {
            recordFailure(failure)
        }
        rebuild()
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

    /// Load a single plugin from a manifest URL. `verifyHash` enforces the manifest `sha256`.
    @discardableResult
    public func loadPlugin(manifestURL: URL, source: Source, verifyHash: Bool) -> PluginID? {
        do {
            let loaded = try PluginLoader.load(manifestURL: manifestURL, verifyHash: verifyHash)
            register(loaded.plugin, manifest: loaded.manifest, source: source)
            rebuild()
            return loaded.plugin.id
        } catch let failure as PluginLoadFailure {
            recordFailure(failure, source: source)
            rebuild()
            return nil
        } catch {
            recordFailure(PluginLoadFailure(manifestName: manifestURL.lastPathComponent,
                                            underlying: nil, message: "\(error)"), source: source)
            rebuild()
            return nil
        }
    }

    private func recordFailure(_ failure: PluginLoadFailure, source: Source = .bundled) {
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

    // MARK: Enable / disable / reload

    public func setEnabled(_ isEnabled: Bool, id: PluginID) {
        enabled[id] = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey(id))
        rebuild()
    }

    /// Remove a plugin from the registry and delete it from the plugin directory.
    ///
    /// A deleted bundled plugin is not reinstalled on the next launch: the install record still
    /// lists it, so `installBundledPlugins` considers it already handled.
    public func removePlugin(id: PluginID) {
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
        for parser in nativeParsers where enabled[parser.id] == true {
            activePlugins.append(parser)
        }
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
