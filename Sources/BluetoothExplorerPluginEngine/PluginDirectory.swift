//
//  PluginDirectory.swift
//  BluetoothExplorerPluginEngine
//
//  On-disk plugin storage under the app's Documents directory.
//
//  Every plugin — bundled or user-imported — lives here, so there is one code path for loading and
//  one place a user can inspect. Bundled plugins are copied in on first launch and refreshed when a
//  new app build ships a different module; a bundled plugin the user deletes stays deleted, because
//  the install record remembers that it was already handled once.
//
//  Layout:
//      Documents/Plugins/
//          <plugin-id>/
//              <name>.bleplugin.json
//              <name>.wasm
//          .installed-bundled.json
//

import Foundation

public struct PluginDirectory: Sendable {

    /// Root of the plugin store, e.g. `Documents/Plugins`.
    public let url: URL

    private static let recordName = ".installed-bundled.json"

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

    // MARK: Listing

    /// Manifest URLs for every installed plugin, one per plugin sub-directory.
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

    public static let manifestSuffix = ".bleplugin.json"

    // MARK: Installing bundled plugins

    /// Copy bundled plugins into the store.
    ///
    /// A plugin is installed when it has never been installed before (first launch), or when the
    /// bundled module's hash differs from the one recorded (a new app build shipped an update).
    /// Plugins the user deleted are not resurrected.
    /// - Returns: the identifiers that were installed or refreshed.
    @discardableResult
    public func installBundledPlugins(from bundle: Bundle) throws -> [String] {
        try createIfNeeded()
        var record = installRecord()
        var installed = [String]()

        let discovered = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Plugins") ?? []
        for manifestURL in discovered.map({ $0 as URL })
        where manifestURL.lastPathComponent.hasSuffix(PluginDirectory.manifestSuffix) {
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data)
            else { continue }

            // The manifest's sha256 identifies this build of the module. Absent one, fall back to
            // the version string so a plugin without a hash still refreshes across releases.
            let stamp = manifest.sha256 ?? manifest.version
            if record[manifest.identifier] == stamp { continue }

            let moduleURL = manifestURL.deletingLastPathComponent()
                .appendingPathComponent(manifest.module)
            try install(manifestURL: manifestURL, moduleURL: moduleURL, identifier: manifest.identifier)
            record[manifest.identifier] = stamp
            installed.append(manifest.identifier)
        }

        try write(record: record)
        return installed
    }

    /// True when no bundled plugin has ever been installed — i.e. this is a first launch.
    public var isFirstLaunch: Bool {
        FileManager.default.fileExists(atPath: recordURL.path) == false
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

    /// Delete an installed plugin's directory.
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

    private var recordURL: URL { url.appendingPathComponent(PluginDirectory.recordName) }

    private func installRecord() -> [String: String] {
        guard let data = try? Data(contentsOf: recordURL),
              let record = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return record
    }

    private func write(record: [String: String]) throws {
        let data = try JSONEncoder().encode(record)
        try data.write(to: recordURL)
    }
}
