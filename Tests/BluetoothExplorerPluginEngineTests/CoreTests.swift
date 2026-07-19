//
//  CoreTests.swift
//  BluetoothExplorerPluginEngineTests
//

import Foundation
import Testing
import Bluetooth
@testable import BluetoothExplorerPluginEngine

@Suite("ABI envelope")
struct EnvelopeTests {

    @Test("Manufacturer envelope layout")
    func manufacturerEnvelope() throws {
        let payload = Data([0x02, 0x15, 0xAA])
        let bytes = PluginABI.encodeEnvelope(kind: .manufacturerData, companyID: 0x004C, uuid: nil, payload: payload)
        #expect(bytes[0] == 1)                 // envelope_version
        #expect(bytes[1] == ParseKind.manufacturerData.rawValue)
        #expect(bytes[2] == 0x4C)              // company LE low
        #expect(bytes[3] == 0x00)              // company LE high
        #expect(Array(bytes[4..<20]) == [UInt8](repeating: 0, count: 16)) // uuid zeroed
        #expect(bytes[20] == 3)                // payload_len LE
        #expect(bytes[21] == 0 && bytes[22] == 0 && bytes[23] == 0)
        #expect(Array(bytes[24...]) == [0x02, 0x15, 0xAA])
    }

    @Test("Characteristic envelope carries big-endian UUID")
    func characteristicEnvelope() throws {
        let uuid = BluetoothUUID.bit16(0x2A19)
        let bytes = PluginABI.encodeEnvelope(kind: .characteristic, companyID: nil, uuid: uuid, payload: Data([0x63]))
        #expect(bytes[1] == ParseKind.characteristic.rawValue)
        #expect(bytes[2] == 0xFF && bytes[3] == 0xFF) // company sentinel
        // 0x2A19 promoted via base UUID: 0000|2A19|-0000-1000-8000-00805F9B34FB, big-endian.
        let expectedUUID: [UInt8] = [0x00, 0x00, 0x2A, 0x19, 0x00, 0x00, 0x10, 0x00,
                                     0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB]
        #expect(Array(bytes[4..<20]) == expectedUUID)
        #expect(Array(bytes[24...]) == [0x63])
    }

    @Test("Result unpacking")
    func unpackResult() {
        #expect(PluginABI.unpackResult(0) == nil)
        let packed: UInt64 = (UInt64(256) << 32) | 41
        let region = PluginABI.unpackResult(packed)
        #expect(region?.pointer == 256)
        #expect(region?.length == 41)
    }
}

@Suite("MicroCBOR")
struct MicroCBORTests {

    @Test("Decodes the battery-level output template")
    func decodesBatteryTemplate() throws {
        // A2 00 67 "Battery" 01 81 A4 00 65 "level" 01 6D "Battery Level" 02 18 5A 03 61 25
        let bytes: [UInt8] = [
            0xA2, 0x00, 0x67, 0x42, 0x61, 0x74, 0x74, 0x65, 0x72, 0x79, 0x01, 0x81,
            0xA4, 0x00, 0x65, 0x6C, 0x65, 0x76, 0x65, 0x6C, 0x01, 0x6D, 0x42, 0x61,
            0x74, 0x74, 0x65, 0x72, 0x79, 0x20, 0x4C, 0x65, 0x76, 0x65, 0x6C, 0x02,
            0x18, 0x5A, 0x03, 0x61, 0x25
        ]
        let result = try DecodedResult.decode(cbor: bytes, pluginID: PluginID("test"))
        #expect(result.title == "Battery")
        #expect(result.fields.count == 1)
        let field = try #require(result.fields.first)
        #expect(field.key == "level")
        #expect(field.label == "Battery Level")
        #expect(field.value == .uint(0x5A))
        #expect(field.unit == "%")
    }

    @Test("Rejects trailing bytes")
    func rejectsTrailing() {
        #expect(throws: MicroCBORError.self) {
            _ = try MicroCBOR.decode([0x00, 0xFF])
        }
    }

    @Test("Enforces item-count cap")
    func enforcesCountCap() {
        // array header declaring 100 items exceeds the default cap of 64 and is rejected up front.
        #expect(throws: MicroCBORError.self) {
            _ = try MicroCBOR.decode([0x98, 100])
        }
    }

    @Test("Decodes tag-37 UUID")
    func decodesUUIDTag() throws {
        var bytes: [UInt8] = [0xD8, 37, 0x50] // tag(37) bytes(16)
        bytes += (0..<16).map { UInt8($0) }
        let value = try MicroCBOR.decode(bytes)
        #expect(value == .uuid((0..<16).map { UInt8($0) }))
    }
}

@Suite("Native parsers")
struct NativeParserTests {

    @Test("iBeacon decode")
    func iBeacon() async throws {
        // type 0x02, len 0x15, uuid(16), major 0x0001, minor 0x0002, rssi 0xC5 (-59)
        var payload: [UInt8] = [0x02, 0x15]
        payload += (0..<16).map { UInt8($0 + 1) }
        payload += [0x00, 0x01, 0x00, 0x02, 0xC5]
        let request = ParseRequest(kind: .manufacturerData, companyID: 0x004C, payload: Data(payload))
        let result = try #require(await NativeIBeaconParser().parse(request))
        #expect(result.title == "iBeacon")
        #expect(result.fields.first(where: { $0.key == "major" })?.value == .uint(1))
        #expect(result.fields.first(where: { $0.key == "minor" })?.value == .uint(2))
        #expect(result.fields.first(where: { $0.key == "tx_power" })?.value == .int(-59))
    }

    @Test("Non-Apple company is ignored")
    func iBeaconWrongCompany() async {
        let request = ParseRequest(kind: .manufacturerData, companyID: 0x0075, payload: Data([0x02, 0x15]))
        #expect(await NativeIBeaconParser().parse(request) == nil)
    }

    @Test("Battery level and string characteristics")
    func wellKnown() async throws {
        let parser = NativeWellKnownCharacteristicParser()
        let battery = try #require(await parser.parse(
            ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([99]))))
        #expect(battery.fields.first?.value == .uint(99))
        #expect(battery.fields.first?.unit == "%")

        let name = try #require(await parser.parse(
            ParseRequest(kind: .characteristic, uuid: .bit16(0x2A29), payload: Data("Acme".utf8))))
        #expect(name.fields.first?.value == .string("Acme"))
    }
}

@Suite("Registry routing")
struct RegistryTests {

    @Test("Routes to matching plugin only")
    func routing() async {
        let registry = ParserRegistry(plugins: [NativeIBeaconParser(), NativeWellKnownCharacteristicParser()])
        // No plugin claims company 0x0075 → empty.
        let none = await registry.decodeAll(ParseRequest(kind: .manufacturerData, companyID: 0x0075, payload: Data()))
        #expect(none.isEmpty)
        // Battery routes to the well-known parser.
        let battery = await registry.decodeFirst(
            ParseRequest(kind: .characteristic, uuid: .bit16(0x2A19), payload: Data([50])))
        #expect(battery?.fields.first?.value == .uint(50))
    }
}
