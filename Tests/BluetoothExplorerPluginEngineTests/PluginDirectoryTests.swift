//
//  PluginDirectoryTests.swift
//  BluetoothExplorerPluginEngineTests
//
//  Covers the Documents-backed store for user-imported plugins: import validation, that a bad
//  import writes nothing, deletion, and identifier-to-folder-name sanitising.
//
//  Bundled plugins are not stored here (they are referenced read-only from the app bundle), so
//  these tests stage a bundled plugin's files into a scratch directory to stand in for a user's
//  imported file. Every test runs against a temporary directory — never the real Documents folder.
//

import Foundation
import Testing
@testable import BluetoothExplorerPluginEngine

@Suite("Plugin directory")
struct PluginDirectoryTests {

    private func makeTemporaryDirectory() throws -> PluginDirectory {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bleplug-store-\(UUID().uuidString)", isDirectory: true)
        let directory = PluginDirectory(url: url)
        try directory.createIfNeeded()
        return directory
    }

    /// Copy one bundled plugin's manifest and module into a fresh scratch directory, standing in
    /// for a file the user picked from outside the app. Returns the staged manifest URL.
    private func stageBundledPlugin() throws -> URL {
        let manifestURLs = (PluginEngineResources.bundle.urls(
            forResourcesWithExtension: "json", subdirectory: "Plugins") ?? [])
            .map { $0 as URL }
            .filter { $0.lastPathComponent.hasSuffix(PluginDirectory.manifestSuffix) }
        let manifestURL = try #require(manifestURLs.first)
        let manifest = try JSONDecoder().decode(
            PluginManifest.self, from: try Data(contentsOf: manifestURL))
        let moduleURL = manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.module)

        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bleplug-stage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let stagedManifest = scratch.appendingPathComponent(manifestURL.lastPathComponent)
        try Data(contentsOf: manifestURL).write(to: stagedManifest)
        try Data(contentsOf: moduleURL).write(to: scratch.appendingPathComponent(manifest.module))
        return stagedManifest
    }

    @Test("Importing a valid plugin copies it into the store and loads")
    func importValidPlugin() throws {
        let destination = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: destination.url) }
        let staged = try stageBundledPlugin()
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }

        let manifest = try destination.importPlugin(manifestURL: staged)
        #expect(destination.installedManifestURLs().count == 1)
        // The imported copy must load and verify against its own hash.
        let installed = try #require(destination.installedManifestURLs().first)
        let loaded = try PluginLoader.load(manifestURL: installed, verifyHash: true)
        #expect(loaded.manifest.identifier == manifest.identifier)
    }

    @Test("Importing a plugin with a wrong hash fails and writes nothing")
    func importRejectsBadHash() throws {
        let destination = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: destination.url) }
        let staged = try stageBundledPlugin()
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }

        // Corrupt the manifest's hash in place.
        let data = try Data(contentsOf: staged)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["sha256"] = String(repeating: "0", count: 64)
        try JSONSerialization.data(withJSONObject: json).write(to: staged)

        #expect(throws: (any Error).self) {
            _ = try destination.importPlugin(manifestURL: staged)
        }
        // Validation happens before anything is written, so the store stays empty.
        #expect(destination.installedManifestURLs().isEmpty)
    }

    @Test("An imported plugin can be removed")
    func removeImportedPlugin() throws {
        let destination = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: destination.url) }
        let staged = try stageBundledPlugin()
        defer { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }

        let manifest = try destination.importPlugin(manifestURL: staged)
        #expect(destination.installedManifestURLs().count == 1)

        try destination.remove(identifier: manifest.identifier)
        #expect(destination.installedManifestURLs().isEmpty)
        // Removing something that is not there is a no-op, not an error.
        try destination.remove(identifier: manifest.identifier)
    }

    @Test("Identifiers map to filesystem-safe folder names")
    func folderNames() {
        #expect(PluginDirectory.folderName(for: "org.pureswift.plugin.gatt-time") == "org.pureswift.plugin.gatt-time")
        #expect(PluginDirectory.folderName(for: "a/b:c") == "a_b_c")
        #expect(PluginDirectory.folderName(for: "").isEmpty == false)
    }
}
