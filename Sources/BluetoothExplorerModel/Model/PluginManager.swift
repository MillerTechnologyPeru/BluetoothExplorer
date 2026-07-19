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

    /// Scan the engine bundle's `Plugins/` directory for `*.bleplugin.json` manifests.
    public func loadBundledPlugins() {
        loadBundledPlugins(from: PluginEngineResources.bundle)
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
        if enabled[id] == nil { enabled[id] = true }
        sources[id] = source
        displayNames[id] = manifest.name
        versions[id] = manifest.version
        loadErrors[id] = nil
    }

    // MARK: Enable / disable / reload

    public func setEnabled(_ isEnabled: Bool, id: PluginID) {
        enabled[id] = isEnabled
        rebuild()
    }

    public func removePlugin(id: PluginID) {
        wasmPlugins[id] = nil
        order.removeAll { $0 == id }
        enabled[id] = nil
        sources[id] = nil
        displayNames[id] = nil
        versions[id] = nil
        loadErrors[id] = nil
        rebuild()
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
