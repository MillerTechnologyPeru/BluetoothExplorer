//
//  GATTPluginTests.swift
//  BluetoothExplorerPluginEngineTests
//
//  Runs every bundled GATT characteristic plugin under the WasmKit interpreter.
//
//  The plugins are Embedded Swift ports of BluetoothGATT's parsers, so BluetoothGATT itself is
//  linked here as an oracle: the same bytes go through both, and they must agree on whether the
//  value is valid. Where a plugin deliberately diverges from the library, the divergence is listed
//  in `knownDivergences` with its reason rather than being silently tolerated.
//

import Foundation
import Testing
import Bluetooth
import BluetoothGATT
@testable import BluetoothExplorerPluginEngine

// MARK: - Fixtures

/// Every UUID each bundled GATT plugin claims, keyed by plugin identifier suffix.
private let expectedCoverage: [String: [UInt16]] = [
    "gatt-device-information": [0x2A23, 0x2A24, 0x2A25, 0x2A26, 0x2A27, 0x2A28, 0x2A29, 0x2A50],
    "gatt-battery": [0x2A19, 0x2BF0],
    "gatt-time": [0x2A08, 0x2A09, 0x2A0A, 0x2A0C, 0x2A0D, 0x2A0E, 0x2A0F, 0x2A11,
                  0x2A12, 0x2A13, 0x2A14, 0x2A16, 0x2A17, 0x2A2B, 0x2AED],
    "gatt-alert-notification": [0x2A06, 0x2A3F, 0x2A42, 0x2A43, 0x2A44, 0x2A45, 0x2A46, 0x2A47, 0x2A48],
    "gatt-blood-pressure": [0x2A35, 0x2A49],
    "gatt-body-fitness": [0x2A38, 0x2A9C, 0x2ACE],
    "gatt-user-data": [0x2A7E, 0x2A7F, 0x2A80, 0x2A81, 0x2A82, 0x2A84],
    "gatt-indoor-positioning": [0x2AAD, 0x2AAE, 0x2AAF, 0x2AB0, 0x2AB1, 0x2AB2, 0x2AB3, 0x2AB4, 0x2AB5],
    "gatt-object-transfer": [0x2ABE, 0x2ABF, 0x2AC0, 0x2AC3],
    "gatt-generic-service": [0x2A05, 0x2A31, 0x2A4F, 0x2AA6, 0x2B29, 0x2B2A, 0x2BF5],
    "gatt-hid": [0x2A22, 0x2A32, 0x2A33],
    "gatt-misc": [0x2AA3, 0x2AAB, 0x2B88]
]

/// A corpus of payloads spanning the lengths and bit patterns these characteristics use.
private func payloadCorpus() -> [Data] {
    var corpus = [Data]()
    corpus.append(Data())
    for length in 1...26 {
        corpus.append(Data(repeating: 0x00, count: length))
        corpus.append(Data(repeating: 0x01, count: length))
        corpus.append(Data(repeating: 0xFF, count: length))
        corpus.append(Data((0..<length).map { UInt8($0 &+ 1) }))
    }
    return corpus
}

/// BluetoothGATT parsers used as the oracle, by characteristic UUID.
///
/// Only bounds-safe types are listed. `GATTBloodPressureMeasurement` is deliberately absent: it
/// checks `data.count >= 1` and then indexes `data[1...6]`, so calling it with a short value traps
/// and would take the whole test process down.
private func oracle() -> [UInt16: @Sendable (Data) -> Bool] { [
    0x2A19: { GATTBatteryLevel(data: $0) != nil },
    0x2A23: { GATTSystemID(data: $0) != nil },
    0x2A24: { GATTModelNumber(data: $0) != nil },
    0x2A25: { GATTSerialNumberString(data: $0) != nil },
    0x2A26: { GATTFirmwareRevisionString(data: $0) != nil },
    0x2A27: { GATTHardwareRevisionString(data: $0) != nil },
    0x2A28: { GATTSoftwareRevisionString(data: $0) != nil },
    0x2A29: { GATTManufacturerNameString(data: $0) != nil },
    0x2A50: { GATTPnPID(data: $0) != nil },
    0x2A06: { GATTAlertLevel(data: $0) != nil },
    0x2A43: { GATTAlertCategory(data: $0) != nil },
    0x2A38: { GATTBodySensorLocation(data: $0) != nil },
    0x2A7E: { GATTAerobicHeartRateLowerLimit(data: $0) != nil },
    0x2A7F: { GATTAerobicThreshold(data: $0) != nil },
    0x2A80: { GATTAge(data: $0) != nil },
    0x2A81: { GATTAnaerobicHeartRateLowerLimit(data: $0) != nil },
    0x2A82: { GATTAnaerobicHeartRateUpperLimit(data: $0) != nil },
    0x2A84: { GATTAerobicHeartRateUpperLimit(data: $0) != nil },
    0x2A05: { GATTServiceChanged(data: $0) != nil },
    0x2A31: { GATTScanRefresh(data: $0) != nil },
    0x2AA6: { GATTCentralAddressResolution(data: $0) != nil },
    0x2B2A: { GATTDatabaseHash(data: $0) != nil },
    0x2AA3: { GATTBarometricPressureTrend(data: $0) != nil },
    0x2AB2: { GATTFloorNumber(data: $0) != nil },
    0x2AB3: { GATTAltitude(data: $0) != nil },
    0x2AAE: { GATTLatitude(data: $0) != nil },
    0x2AAF: { GATTLongitude(data: $0) != nil },
    0x2AB0: { GATTLocalNorthCoordinate(data: $0) != nil },
    0x2AB1: { GATTLocalEastCoordinate(data: $0) != nil },
    0x2A22: { GATTBootKeyboardInputReport(data: $0) != nil },
    0x2A32: { GATTBootKeyboardOutputReport(data: $0) != nil },
    0x2A33: { GATTBootMouseInputReport(data: $0) != nil },
    0x2ABF: { GATTObjectType(data: $0) != nil },
    0x2AC0: { GATTObjectSize(data: $0) != nil },
    0x2AC3: { GATTObjectID(data: $0) != nil }
] }

/// Characteristics where the plugin intentionally does not match the library, with the reason.
private let knownDivergences: [UInt16: String] = [:]

// MARK: - Tests

// Serialized: each test loads all 13 bundled plugins, and every plugin holds its own warm
// interpreter instance on its own thread. Running these tests concurrently multiplies that into
// dozens of contending interpreters, which is a property of the test harness rather than of the
// engine, and makes per-call latency wildly variable.
@Suite("GATT characteristic plugins", .serialized)
struct GATTPluginTests {

    private func loadAll() throws -> [LoadedPlugin] {
        let result = PluginLoader.loadBundled(from: PluginEngineResources.bundle)
        #expect(result.failures.isEmpty, "load failures: \(result.failures.map(\.message))")
        return result.loaded
    }

    private func plugin(_ suffix: String, in loaded: [LoadedPlugin]) throws -> any ParserPlugin {
        try #require(
            loaded.first { $0.manifest.identifier == "org.pureswift.plugin." + suffix }?.plugin,
            "plugin \(suffix) is not bundled"
        )
    }

    @Test("Every GATT group plugin loads and passes hash verification")
    func allGroupPluginsLoad() throws {
        let loaded = try loadAll()
        for suffix in expectedCoverage.keys {
            let identifier = "org.pureswift.plugin." + suffix
            #expect(loaded.contains { $0.manifest.identifier == identifier }, "missing \(suffix)")
        }
    }

    @Test("Manifests declare exactly the 71 GATT characteristics, with no duplicates")
    func manifestCoverageIsComplete() throws {
        let loaded = try loadAll()
        var claimed = [UInt16: String]()
        for entry in loaded where entry.manifest.identifier.contains(".gatt-") {
            for uuid in entry.manifest.characteristicBluetoothUUIDs {
                guard case let .bit16(value) = uuid else { continue }
                #expect(claimed[value] == nil,
                        "0x\(String(value, radix: 16)) claimed by both \(claimed[value] ?? "") and \(entry.manifest.identifier)")
                claimed[value] = entry.manifest.identifier
            }
        }
        let expected = Set(expectedCoverage.values.flatMap { $0 })
        #expect(claimed.count == 71, "expected 71 characteristics, found \(claimed.count)")
        #expect(Set(claimed.keys) == expected, "manifest UUIDs differ from the expected set")
    }

    @Test("Every declared UUID actually decodes something under the interpreter")
    func everyDeclaredUUIDDecodes() async throws {
        let loaded = try loadAll()
        var undecodable = [String]()
        for (suffix, uuids) in expectedCoverage {
            let plugin = try plugin(suffix, in: loaded)
            for uuid in uuids {
                var decoded = false
                for payload in payloadCorpus() {
                    let request = ParseRequest(kind: .characteristic, uuid: .bit16(uuid), payload: payload)
                    if let result = await plugin.parse(request), result.fields.isEmpty == false {
                        decoded = true
                        break
                    }
                }
                if decoded == false {
                    undecodable.append("\(suffix)/0x\(String(uuid, radix: 16, uppercase: true))")
                }
            }
        }
        #expect(undecodable.isEmpty, "declared but never decodes: \(undecodable)")
    }

    @Test("Plugins decline UUIDs they do not declare")
    func undeclaredUUIDsAreDeclined() async throws {
        let loaded = try loadAll()
        for (suffix, uuids) in expectedCoverage {
            let plugin = try plugin(suffix, in: loaded)
            let owned = Set(uuids)
            // Probe a handful of UUIDs owned by *other* groups plus one that exists nowhere.
            let foreign = Set(expectedCoverage.values.flatMap { $0 }).subtracting(owned).prefix(6) + [0xFFF0]
            for uuid in foreign {
                let request = ParseRequest(kind: .characteristic, uuid: .bit16(uuid), payload: Data([1, 2, 3, 4]))
                #expect(await plugin.parse(request) == nil,
                        "\(suffix) accepted foreign UUID 0x\(String(uuid, radix: 16, uppercase: true))")
            }
        }
    }

    @Test("No plugin traps or gets quarantined on the payload corpus")
    func pluginsSurviveCorpus() async throws {
        let loaded = try loadAll()
        for (suffix, uuids) in expectedCoverage {
            let entry = try #require(loaded.first { $0.manifest.identifier == "org.pureswift.plugin." + suffix })
            for uuid in uuids {
                for payload in payloadCorpus() {
                    let request = ParseRequest(kind: .characteristic, uuid: .bit16(uuid), payload: payload)
                    _ = await entry.plugin.parse(request)
                }
            }
            // A trap, bad result region or timeout would have quarantined the plugin by now.
            #expect(entry.plugin.isQuarantined == false, "\(suffix) was quarantined by the corpus")
        }
    }

    @Test("Plugins agree with BluetoothGATT on which values are valid")
    func parityWithBluetoothGATT() async throws {
        let loaded = try loadAll()
        var pluginsByUUID = [UInt16: any ParserPlugin]()
        for (suffix, uuids) in expectedCoverage {
            let plugin = try plugin(suffix, in: loaded)
            for uuid in uuids { pluginsByUUID[uuid] = plugin }
        }

        var mismatches = [String]()
        for (uuid, accepts) in oracle() {
            if knownDivergences[uuid] != nil { continue }
            let plugin = try #require(pluginsByUUID[uuid])
            for payload in payloadCorpus() {
                let request = ParseRequest(kind: .characteristic, uuid: .bit16(uuid), payload: payload)
                let pluginAccepted = await plugin.parse(request) != nil
                let libraryAccepted = accepts(payload)
                if pluginAccepted != libraryAccepted {
                    mismatches.append(
                        "0x\(String(uuid, radix: 16, uppercase: true)) len=\(payload.count) "
                        + "plugin=\(pluginAccepted) library=\(libraryAccepted)")
                }
            }
        }
        let report = "accept/reject mismatches vs BluetoothGATT:\n" + mismatches.prefix(25).joined(separator: "\n")
        #expect(mismatches.isEmpty, Comment(rawValue: report))
    }

    @Test("Spot-check decoded values against hand-computed expectations")
    func decodedValues() async throws {
        let loaded = try loadAll()

        // Battery Level 0x2A19
        let battery = try plugin("gatt-battery", in: loaded)
        let level = try #require(await battery.parse(
            ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([77]))))
        #expect(level.fields.first?.value == .uint(77))
        #expect(level.fields.first?.unit == "%")

        // Manufacturer Name String 0x2A29
        let deviceInfo = try plugin("gatt-device-information", in: loaded)
        let name = try #require(await deviceInfo.parse(
            ParseRequest(kind: .characteristic, uuid: .bit16(0x2A29), payload: Data("PureSwift".utf8))))
        #expect(name.fields.first?.value == .string("PureSwift"))

        // PnP ID 0x2A50: source=1 (SIG), vendor=0x004C, product=0x1234, version=0x0100
        let pnp = try #require(await deviceInfo.parse(ParseRequest(
            kind: .characteristic, uuid: .bit16(0x2A50),
            payload: Data([0x01, 0x4C, 0x00, 0x34, 0x12, 0x00, 0x01]))))
        #expect(pnp.fields.contains { $0.key == "vendor_id" && $0.value == .uint(0x004C) })
        #expect(pnp.fields.contains { $0.key == "product_id" && $0.value == .uint(0x1234) })
        #expect(pnp.fields.contains { $0.key == "product_version" && $0.value == .uint(0x0100) })

        // Service Changed 0x2A05: start 0x0001, end 0xFFFF
        let generic = try plugin("gatt-generic-service", in: loaded)
        let changed = try #require(await generic.parse(ParseRequest(
            kind: .characteristic, uuid: .bit16(0x2A05), payload: Data([0x01, 0x00, 0xFF, 0xFF]))))
        #expect(changed.fields.contains { $0.value == .uint(0x0001) })
        #expect(changed.fields.contains { $0.value == .uint(0xFFFF) })
    }
}
