//
//  WasmTests.swift
//  BluetoothExplorerPluginEngineTests
//
//  Exercises the WASM runner against hand-written WAT fixtures compiled at test time, plus the
//  bundled GATT plugins, and checks parity against the native parsers.
//

import Foundation
import Testing
import Bluetooth
import WAT
@testable import BluetoothExplorerPluginEngine

private let batteryWAT = """
(module
  (memory (export "memory") 1)
  (global $bump (mut i32) (i32.const 1024))
  (data (i32.const 256) "\\a2\\00\\67\\42\\61\\74\\74\\65\\72\\79\\01\\81\\a4\\00\\65\\6c\\65\\76\\65\\6c\\01\\6d\\42\\61\\74\\74\\65\\72\\79\\20\\4c\\65\\76\\65\\6c\\02\\18\\00\\03\\61\\25")
  (func (export "bleplug_abi_1"))
  (func (export "bleplug_alloc") (param $size i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (global.get $bump))
    (global.set $bump (i32.add (global.get $bump) (local.get $size)))
    (local.get $ptr))
  (func (export "bleplug_parse_characteristic") (param $ptr i32) (param $len i32) (result i64)
    (if (i32.eqz (i32.load (i32.add (local.get $ptr) (i32.const 20))))
      (then (return (i64.const 0))))
    (i32.store8 (i32.const 293) (i32.load8_u (i32.add (local.get $ptr) (i32.const 24))))
    (i64.or (i64.shl (i64.const 256) (i64.const 32)) (i64.const 41)))
)
"""

private func batteryManifest(sha: String? = nil) -> PluginManifest {
    PluginManifest(
        identifier: "test.battery",
        name: "Battery",
        version: "1.0.0",
        module: "battery.wasm",
        sha256: sha,
        matches: .init(characteristicUUIDs: ["2A19"]),
        limits: .init(maxMemoryPages: 2, maxOutputBytes: 256)
    )
}

@Suite("WASM runner")
struct WasmRunnerTests {

    @Test("Well-behaved plugin round-trips to a DecodedResult")
    func batteryRoundTrip() async throws {
        let wasm = try [UInt8](wat2wasm(batteryWAT))
        let plugin = try WasmParserPlugin(manifest: batteryManifest(), moduleBytes: wasm)
        let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([0x5A]))
        let result = try #require(await plugin.parse(request))
        #expect(result.title == "Battery")
        #expect(result.fields.first?.value == .uint(0x5A))
        #expect(result.fields.first?.unit == "%")
    }

    @Test("Empty payload yields no result, not an error")
    func batteryEmpty() async throws {
        let wasm = try [UInt8](wat2wasm(batteryWAT))
        let plugin = try WasmParserPlugin(manifest: batteryManifest(), moduleBytes: wasm)
        let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data())
        #expect(await plugin.parse(request) == nil)
    }

    @Test("Module importing a host function is rejected at load")
    func rejectsImports() throws {
        let wat = """
        (module
          (import "host" "log" (func $log (param i32)))
          (memory (export "memory") 1)
          (func (export "bleplug_abi_1"))
          (func (export "bleplug_alloc") (param i32) (result i32) (i32.const 0)))
        """
        let wasm = try [UInt8](wat2wasm(wat))
        let manifest = batteryManifest()
        #expect(throws: PluginError.self) {
            _ = try WasmParserPlugin(manifest: manifest, moduleBytes: wasm)
        }
    }

    @Test("Missing capability export is rejected at load")
    func rejectsMissingCapability() throws {
        // Declares characteristic capability but exports no parse_characteristic.
        let wat = """
        (module
          (memory (export "memory") 1)
          (func (export "bleplug_abi_1"))
          (func (export "bleplug_alloc") (param i32) (result i32) (i32.const 1024)))
        """
        let wasm = try [UInt8](wat2wasm(wat))
        #expect(throws: PluginError.self) {
            _ = try WasmParserPlugin(manifest: batteryManifest(), moduleBytes: wasm)
        }
    }

    @Test("Out-of-bounds result region is caught")
    func rejectsBadResultRegion() async throws {
        // Returns a huge pointer/length that lies outside linear memory.
        let wat = """
        (module
          (memory (export "memory") 1)
          (func (export "bleplug_abi_1"))
          (func (export "bleplug_alloc") (param i32) (result i32) (i32.const 1024))
          (func (export "bleplug_parse_characteristic") (param i32) (param i32) (result i64)
            (i64.or (i64.shl (i64.const 0xF0000000) (i64.const 32)) (i64.const 16))))
        """
        let wasm = try [UInt8](wat2wasm(wat))
        let plugin = try WasmParserPlugin(manifest: batteryManifest(), moduleBytes: wasm)
        // parse() swallows the error and returns nil; the failure is recorded internally.
        let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([1]))
        #expect(await plugin.parse(request) == nil)
    }

    @Test("Infinite loop trips the deadline and quarantines")
    func deadlineQuarantine() async throws {
        let wat = """
        (module
          (memory (export "memory") 1)
          (func (export "bleplug_abi_1"))
          (func (export "bleplug_alloc") (param i32) (result i32) (i32.const 1024))
          (func (export "bleplug_parse_characteristic") (param i32) (param i32) (result i64)
            (loop $l (br $l))
            (i64.const 0)))
        """
        let wasm = try [UInt8](wat2wasm(wat))
        let plugin = try WasmParserPlugin(
            manifest: batteryManifest(),
            moduleBytes: wasm,
            deadline: .milliseconds(50),
            warmupDeadline: .seconds(2)
        )
        let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([1]))
        #expect(await plugin.parse(request) == nil)
        // Give the timeout task a moment to flip the quarantine flag.
        try await Task.sleep(for: .milliseconds(100))
        #expect(plugin.isQuarantined)
    }

    @Test("WASM battery output matches the native parser")
    func wasmNativeParity() async throws {
        let wasm = try [UInt8](wat2wasm(batteryWAT))
        let wasmPlugin = try WasmParserPlugin(manifest: batteryManifest(), moduleBytes: wasm)
        let native = NativeWellKnownCharacteristicParser()
        // 0...100 only: the GATT plugin enforces the spec's valid range, unlike the legacy
        // native parser, so 255 is deliberately excluded here and asserted separately below.
        for level: UInt8 in [0, 1, 42, 99, 100] {
            let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([level]))
            let wasmResult = try #require(await wasmPlugin.parse(request))
            let nativeResult = try #require(await native.parse(request))
            #expect(wasmResult.fields.first?.value == nativeResult.fields.first?.value)
            #expect(wasmResult.fields.first?.value == .uint(UInt64(level)))
        }
    }
}

@Suite("Bundled plugin loading")
struct PluginLoaderTests {

    @Test("Loads the bundled battery plugin and it decodes under the interpreter")
    func loadsBundled() async throws {
        let result = PluginLoader.loadBundled(from: PluginEngineResources.bundle)
        #expect(result.failures.isEmpty, "load failures: \(result.failures.map(\.message))")
        let battery = try #require(result.loaded.first {
            $0.manifest.identifier == "org.pureswift.plugin.gatt-battery"
        })
        // The bundled module (validated against its manifest sha256) decodes a real value.
        let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([88]))
        let decoded = try #require(await battery.plugin.parse(request))
        #expect(decoded.title == "Battery Level")
        #expect(decoded.fields.first?.value == .uint(88))
    }

    @Test("Bundled Embedded Swift plugin matches the native parser across values")
    func bundledSwiftPluginParity() async throws {
        let result = PluginLoader.loadBundled(from: PluginEngineResources.bundle)
        let battery = try #require(result.loaded.first {
            $0.manifest.identifier == "org.pureswift.plugin.gatt-battery"
        })
        let native = NativeWellKnownCharacteristicParser()
        var failures = [UInt8]()
        // 0...100 only: the GATT plugin enforces the spec's valid range, unlike the legacy
        // native parser, so 255 is deliberately excluded here and asserted separately below.
        for level: UInt8 in [0, 1, 42, 99, 100] {
            let request = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([level]))
            guard let wasmResult = await battery.plugin.parse(request) else {
                failures.append(level)
                continue
            }
            let nativeResult = try #require(await native.parse(request))
            #expect(wasmResult.fields.first?.value == .uint(UInt64(level)), "level \(level)")
            #expect(wasmResult.fields.first?.value == nativeResult.fields.first?.value, "level \(level)")
            #expect(wasmResult.fields.first?.unit == "%", "level \(level)")
        }
        #expect(failures.isEmpty, "levels returning nil: \(failures)")

        // Out-of-range battery level: the plugin rejects it (GATTBatteryPercentage is 0...100)
        // where the legacy native parser happily returns 255.
        let invalid = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([255]))
        #expect(await battery.plugin.parse(invalid) == nil)
        #expect(await native.parse(invalid) != nil)
    }

    @Test("Bundled plugin declines a payload it does not recognize")
    func bundledSwiftPluginDeclines() async throws {
        let result = PluginLoader.loadBundled(from: PluginEngineResources.bundle)
        let battery = try #require(result.loaded.first {
            $0.manifest.identifier == "org.pureswift.plugin.gatt-battery"
        })
        // Empty payload: the guest returns 0 ("not mine"), which must surface as nil, not an error.
        let empty = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data())
        #expect(await battery.plugin.parse(empty) == nil)
        // Wrong UUID: the plugin checks its own assigned number.
        let wrong = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A37), payload: Data([1]))
        #expect(await battery.plugin.parse(wrong) == nil)
    }

    @Test("A tampered sha256 is rejected")
    func rejectsHashMismatch() throws {
        let manifestURLs = PluginEngineResources.bundle.urls(
            forResourcesWithExtension: "json", subdirectory: "Plugins") ?? []
        let batteryManifestURL = try #require(manifestURLs.first {
            $0.lastPathComponent == "gatt-battery.bleplugin.json"
        })
        // Write a manifest copy with a wrong hash next to the real module and load it.
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bleplug-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let moduleURL = batteryManifestURL.deletingLastPathComponent().appendingPathComponent("gatt-battery.wasm")
        try Data(contentsOf: moduleURL).write(to: tempDir.appendingPathComponent("gatt-battery.wasm"))
        let badManifest = """
        {"manifestVersion":1,"id":"x","name":"x","version":"1.0.0","abi":1,
         "module":"gatt-battery.wasm","sha256":"deadbeef","matches":{"characteristicUUIDs":["2A19"]}}
        """
        let badManifestURL = tempDir.appendingPathComponent("x.bleplugin.json")
        try Data(badManifest.utf8).write(to: badManifestURL)

        #expect(throws: PluginLoadFailure.self) {
            _ = try PluginLoader.load(manifestURL: badManifestURL, verifyHash: true)
        }
    }
}
