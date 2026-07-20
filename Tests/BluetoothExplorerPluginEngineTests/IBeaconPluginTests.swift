//
//  IBeaconPluginTests.swift
//  BluetoothExplorerPluginEngineTests
//
//  Exercises the advertisement (manufacturer-data) path end to end: the bundled Embedded Swift
//  iBeacon module runs under the interpreter and its output is diffed field-by-field against
//  NativeIBeaconParser. This is the only coverage of `bleplug_parse_manufacturer`.
//

import Foundation
import Testing
import Bluetooth
@testable import BluetoothExplorerPluginEngine

@Suite("iBeacon plugin")
struct IBeaconPluginTests {

    private static let pluginID = "org.pureswift.plugin.ibeacon"

    /// Build an iBeacon manufacturer-data payload (company id already stripped by the host).
    private func payload(
        uuid: [UInt8] = (0..<16).map { UInt8($0 + 1) },
        major: UInt16 = 1,
        minor: UInt16 = 2,
        measuredPower: Int8 = -59
    ) -> Data {
        var bytes: [UInt8] = [0x02, 0x15]
        bytes += uuid
        bytes += [UInt8(major >> 8), UInt8(major & 0xFF)]
        bytes += [UInt8(minor >> 8), UInt8(minor & 0xFF)]
        bytes.append(UInt8(bitPattern: measuredPower))
        return Data(bytes)
    }

    private func loadPlugin() throws -> any ParserPlugin {
        let result = PluginLoader.loadBundled(from: PluginEngineResources.bundle)
        #expect(result.failures.isEmpty, "load failures: \(result.failures.map(\.message))")
        let loaded = try #require(result.loaded.first { $0.manifest.identifier == Self.pluginID })
        return loaded.plugin
    }

    @Test("Bundled module decodes an advertisement under the interpreter")
    func decodesAdvertisement() async throws {
        let plugin = try loadPlugin()
        let request = ParseRequest(kind: .manufacturerData, companyID: 0x004C, payload: payload())
        let result = try #require(await plugin.parse(request))

        #expect(result.title == "iBeacon")
        #expect(result.fields.count == 4)
        #expect(result.fields.first(where: { $0.key == "major" })?.value == .uint(1))
        #expect(result.fields.first(where: { $0.key == "minor" })?.value == .uint(2))
        #expect(result.fields.first(where: { $0.key == "tx_power" })?.value == .int(-59))
        #expect(result.fields.first(where: { $0.key == "tx_power" })?.unit == "dBm")

        // The proximity UUID must survive the envelope's big-endian byte order unchanged.
        let expectedUUID = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        #expect(result.fields.first(where: { $0.key == "uuid" })?.value == .uuid(expectedUUID))
    }

    @Test("WASM output matches the native parser field for field")
    func matchesNativeParser() async throws {
        let plugin = try loadPlugin()
        let native = NativeIBeaconParser()

        let cases: [(UInt16, UInt16, Int8)] = [
            (0, 0, 0),
            (1, 2, -59),
            (0x1234, 0xABCD, -100),
            (UInt16.max, UInt16.max, 127),
            (256, 1, -128)
        ]
        for (major, minor, power) in cases {
            let request = ParseRequest(
                kind: .manufacturerData,
                companyID: 0x004C,
                payload: payload(major: major, minor: minor, measuredPower: power)
            )
            let wasmResult = try #require(await plugin.parse(request), "wasm declined \(major)/\(minor)")
            let nativeResult = try #require(await native.parse(request))

            #expect(wasmResult.title == nativeResult.title, "major \(major)")
            #expect(wasmResult.fields.count == nativeResult.fields.count, "major \(major)")
            for (wasmField, nativeField) in zip(wasmResult.fields, nativeResult.fields) {
                #expect(wasmField.key == nativeField.key)
                #expect(wasmField.label == nativeField.label)
                #expect(wasmField.value == nativeField.value, "field \(wasmField.key), major \(major)")
                #expect(wasmField.unit == nativeField.unit)
            }
        }
    }

    @Test("Non-iBeacon Apple payloads are declined, like the native parser")
    func declinesNonBeacon() async throws {
        let plugin = try loadPlugin()
        let native = NativeIBeaconParser()

        // Apple uses this company id for many formats; only 0x02/0x15 is an iBeacon.
        let notBeacons: [Data] = [
            Data(),                                     // empty
            Data([0x02]),                               // truncated
            Data([0x10, 0x05, 0x01, 0x02, 0x03]),       // continuity/handoff-style payload
            Data([0x02, 0x15] + [UInt8](repeating: 0, count: 10)),  // right type, wrong length
            Data([0x02, 0x16] + [UInt8](repeating: 0, count: 21))    // wrong length byte
        ]
        for data in notBeacons {
            let request = ParseRequest(kind: .manufacturerData, companyID: 0x004C, payload: data)
            #expect(await plugin.parse(request) == nil, "wasm accepted \(data as NSData)")
            #expect(await native.parse(request) == nil, "native accepted \(data as NSData)")
        }
    }

    @Test("Routing sends Apple manufacturer data to the plugin, other companies nowhere")
    func routing() async throws {
        let plugin = try loadPlugin()
        let registry = ParserRegistry(plugins: [plugin])

        let apple = ParseRequest(kind: .manufacturerData, companyID: 0x004C, payload: payload())
        #expect(await registry.decodeAll(apple).count == 1)

        // A different company must not reach the plugin at all.
        let other = ParseRequest(kind: .manufacturerData, companyID: 0x0075, payload: payload())
        #expect(await registry.decodeAll(other).isEmpty)

        // Same bytes arriving as a characteristic value must not route here either.
        let wrongKind = ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: payload())
        #expect(await registry.decodeAll(wrongKind).isEmpty)
    }
}
