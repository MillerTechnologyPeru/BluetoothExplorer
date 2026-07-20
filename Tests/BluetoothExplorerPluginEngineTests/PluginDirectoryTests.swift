//
//  PluginDirectoryTests.swift
//  BluetoothExplorerPluginEngineTests
//
//  Covers the Documents-backed plugin store: first-launch install of the bundled plugins,
//  idempotence across launches, that a deleted bundled plugin stays deleted, and import validation.
//
//  Every test runs against a temporary directory — never the real Documents folder.
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

    private func bundledManifestCount() -> Int {
        let urls = PluginEngineResources.bundle.urls(
            forResourcesWithExtension: "json", subdirectory: "Plugins") ?? []
        return urls.map { $0 as URL }
            .filter { $0.lastPathComponent.hasSuffix(PluginDirectory.manifestSuffix) }
            .count
    }

    @Test("First launch installs every bundled plugin")
    func firstLaunchInstalls() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        #expect(directory.isFirstLaunch)
        let installed = try directory.installBundledPlugins(from: PluginEngineResources.bundle)
        #expect(installed.count == bundledManifestCount())
        #expect(installed.isEmpty == false)
        #expect(directory.isFirstLaunch == false)
        #expect(directory.installedManifestURLs().count == installed.count)
    }

    @Test("Installed plugins load from the directory")
    func installedPluginsLoad() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }
        try directory.installBundledPlugins(from: PluginEngineResources.bundle)

        for manifestURL in directory.installedManifestURLs() {
            // Hash verification is on: a copy that lost bytes would fail here.
            _ = try PluginLoader.load(manifestURL: manifestURL, verifyHash: true)
        }
    }

    @Test("A second launch installs nothing new")
    func secondLaunchIsIdempotent() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let first = try directory.installBundledPlugins(from: PluginEngineResources.bundle)
        let second = try directory.installBundledPlugins(from: PluginEngineResources.bundle)
        #expect(second.isEmpty, "reinstalled on second launch: \(second)")
        #expect(directory.installedManifestURLs().count == first.count)
    }

    @Test("A deleted bundled plugin is not resurrected on the next launch")
    func deletedPluginStaysDeleted() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let installed = try directory.installBundledPlugins(from: PluginEngineResources.bundle)
        let victim = try #require(installed.first)
        try directory.remove(identifier: victim)
        #expect(directory.installedManifestURLs().count == installed.count - 1)

        let afterRelaunch = try directory.installBundledPlugins(from: PluginEngineResources.bundle)
        #expect(afterRelaunch.isEmpty, "deleted plugin came back: \(afterRelaunch)")
        #expect(directory.installedManifestURLs().count == installed.count - 1)
    }

    @Test("Importing a valid plugin copies it into the store")
    func importValidPlugin() throws {
        let source = try makeTemporaryDirectory()
        let destination = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source.url)
            try? FileManager.default.removeItem(at: destination.url)
        }
        // Stage a plugin outside the store, the way a user's file would arrive.
        try source.installBundledPlugins(from: PluginEngineResources.bundle)
        let staged = try #require(source.installedManifestURLs().first)

        let manifest = try destination.importPlugin(manifestURL: staged)
        #expect(destination.installedManifestURLs().count == 1)
        // The imported copy must load and verify against its own hash.
        let installed = try #require(destination.installedManifestURLs().first)
        let loaded = try PluginLoader.load(manifestURL: installed, verifyHash: true)
        #expect(loaded.manifest.identifier == manifest.identifier)
    }

    @Test("Importing a plugin with a wrong hash fails and writes nothing")
    func importRejectsBadHash() throws {
        let source = try makeTemporaryDirectory()
        let destination = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: source.url)
            try? FileManager.default.removeItem(at: destination.url)
        }
        try source.installBundledPlugins(from: PluginEngineResources.bundle)
        let staged = try #require(source.installedManifestURLs().first)

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

    @Test("Identifiers map to filesystem-safe folder names")
    func folderNames() {
        #expect(PluginDirectory.folderName(for: "org.pureswift.plugin.gatt-time") == "org.pureswift.plugin.gatt-time")
        #expect(PluginDirectory.folderName(for: "a/b:c") == "a_b_c")
        #expect(PluginDirectory.folderName(for: "").isEmpty == false)
    }
}
