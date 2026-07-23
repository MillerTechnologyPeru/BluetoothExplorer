//
//  PluginDirectory.swift
//  BluetoothExplorerPluginEngine
//
//  On-disk storage for user-imported plugins, under the app's Documents directory.
//
//  Bundled plugins are NOT stored here — they are referenced read-only from the app bundle. This
//  directory holds only plugins the user imported, one sub-directory per plugin, so they can be
//  listed, loaded, and deleted.
//
//  Layout:
//      Documents/Plugins/
//          <plugin-id>/
//              <name>.bleplugin.json
//              <name>.wasm
//

import Foundation

public struct PluginDirectory: Sendable {

    /// Root of the imported-plugin store, e.g. `Documents/Plugins`.
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `Documents/Plugins`, created if absent.
    public static func `default`() throws -> PluginDirectory {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = PluginDirectory(url: documents.appendingPathComponent("Plugins", isDirectory: true))
        try directory.createIfNeeded()
        return directory
    }

    public func createIfNeeded() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public static let manifestSuffix = ".bleplugin.json"

    // MARK: Listing

    /// Manifest URLs for every imported plugin, one per plugin sub-directory.
    public func installedManifestURLs() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil)) ?? []
        var manifests = [URL]()
        for entry in contents.map({ $0 as URL }) {
            // `contentsOfDirectory` on a plain file throws, which is a portable directory test —
            // `ObjCBool` out-parameters are awkward outside Darwin's Foundation.
            guard let inner = try? FileManager.default.contentsOfDirectory(
                at: entry, includingPropertiesForKeys: nil)
            else { continue }
            for file in inner.map({ $0 as URL })
            where file.lastPathComponent.hasSuffix(PluginDirectory.manifestSuffix) {
                manifests.append(file)
            }
        }
        return manifests.sorted { $0.path < $1.path }
    }

    // MARK: Importing

    /// Import a plugin the user picked, copying its manifest and module into the store.
    ///
    /// `manifestURL` must be a `*.bleplugin.json`; the module named by the manifest is resolved
    /// alongside it. The plugin is validated before anything is written, so a bad import cannot
    /// leave a broken plugin on disk.
    @discardableResult
    public func importPlugin(manifestURL: URL) throws -> PluginManifest {
        try createIfNeeded()
        // Validate first: this parses the module, checks the ABI marker, capability exports and,
        // when the manifest carries a hash, verifies it.
        let loaded = try PluginLoader.load(manifestURL: manifestURL, verifyHash: true)
        let moduleURL = manifestURL.deletingLastPathComponent()
            .appendingPathComponent(loaded.manifest.module)
        try install(manifestURL: manifestURL, moduleURL: moduleURL,
                    identifier: loaded.manifest.identifier)
        return loaded.manifest
    }

    /// Delete an imported plugin's directory.
    public func remove(identifier: String) throws {
        let directory = url.appendingPathComponent(Self.folderName(for: identifier), isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    // MARK: Internals

    private func install(manifestURL: URL, moduleURL: URL, identifier: String) throws {
        let destination = url.appendingPathComponent(Self.folderName(for: identifier), isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let moduleData = try Data(contentsOf: moduleURL)
        let manifestData = try Data(contentsOf: manifestURL)
        try moduleData.write(to: destination.appendingPathComponent(moduleURL.lastPathComponent))
        try manifestData.write(to: destination.appendingPathComponent(manifestURL.lastPathComponent))
    }

    /// A filesystem-safe directory name for a reverse-DNS plugin identifier.
    public static func folderName(for identifier: String) -> String {
        var name = ""
        for character in identifier {
            if character.isLetter || character.isNumber || character == "." || character == "-" {
                name.append(character)
            } else {
                name.append("_")
            }
        }
        return name.isEmpty ? "plugin" : name
    }
}
