//
//  PluginLoader.swift
//  BluetoothExplorerPluginEngine
//
//  Pure loading/validation of WASM plugins from disk. No UI or observation concerns — the
//  model layer's PluginManager wraps this for @Observable state.
//

import Foundation

/// A successfully loaded plugin and its manifest.
public struct LoadedPlugin: Sendable {
    public let manifest: PluginManifest
    public let plugin: WasmParserPlugin
}

/// A plugin that failed to load, identified by its manifest file name.
public struct PluginLoadFailure: Error, Sendable {
    public let manifestName: String
    public let underlying: PluginError?
    public let message: String

    public init(manifestName: String, underlying: PluginError?, message: String) {
        self.manifestName = manifestName
        self.underlying = underlying
        self.message = message
    }
}

public enum PluginLoader {

    /// Load and validate a single plugin from a manifest URL.
    public static func load(manifestURL: URL, verifyHash: Bool) throws -> LoadedPlugin {
        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent, underlying: nil,
                                    message: "cannot read manifest: \(error)")
        }

        let manifest: PluginManifest
        do {
            manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)
        } catch {
            throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent, underlying: nil,
                                    message: "invalid manifest JSON: \(error)")
        }

        let moduleURL = manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.module)
        guard let moduleData = try? Data(contentsOf: moduleURL) else {
            throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent, underlying: nil,
                                    message: "cannot read module \(manifest.module)")
        }
        let moduleBytes = [UInt8](moduleData)

        if let expected = manifest.sha256 {
            let actual = SHA256.hexDigest(moduleBytes)
            guard actual.lowercased() == expected.lowercased() else {
                throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent,
                                        underlying: .hashMismatch, message: "sha256 mismatch")
            }
        } else if verifyHash {
            throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent,
                                    underlying: .hashMismatch, message: "manifest missing sha256")
        }

        do {
            let plugin = try WasmParserPlugin(manifest: manifest, moduleBytes: moduleBytes)
            return LoadedPlugin(manifest: manifest, plugin: plugin)
        } catch let error as PluginError {
            throw PluginLoadFailure(manifestName: manifestURL.lastPathComponent, underlying: error,
                                    message: "\(error)")
        }
    }

    /// Scan a bundle's `Plugins/` directory for `*.bleplugin.json` manifests and load each.
    public static func loadBundled(from bundle: Bundle) -> (loaded: [LoadedPlugin], failures: [PluginLoadFailure]) {
        let manifestURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Plugins") ?? []
        var loaded = [LoadedPlugin]()
        var failures = [PluginLoadFailure]()
        for url in manifestURLs where url.lastPathComponent.hasSuffix(".bleplugin.json") {
            do {
                loaded.append(try load(manifestURL: url, verifyHash: false))
            } catch let failure as PluginLoadFailure {
                failures.append(failure)
            } catch {
                failures.append(PluginLoadFailure(manifestName: url.lastPathComponent, underlying: nil,
                                                  message: "\(error)"))
            }
        }
        return (loaded, failures)
    }
}
