//
//  NativeParsers.swift
//  BluetoothExplorerPluginEngine
//
//  Built-in Swift parsers registered alongside WASM plugins. They cover what the app decoded
//  before the plugin system existed (iBeacon manufacturer data, well-known characteristics) and
//  serve as the conformance twins for the bundled WASM reference plugins.
//

import Foundation
import Bluetooth

// MARK: - iBeacon

/// Decodes Apple iBeacon manufacturer data (company `0x004C`, type `0x02`, length `0x15`).
public struct NativeIBeaconParser: ParserPlugin {

    public let id = PluginID("org.pureswift.native.ibeacon")
    public let name = "iBeacon"

    private static let appleCompany: UInt16 = 0x004C
    private static let iBeaconType: UInt8 = 0x02
    private static let iBeaconLength: UInt8 = 0x15

    public init() {}

    public var routingKeys: RoutingKeys {
        RoutingKeys(companyIdentifiers: [Self.appleCompany])
    }

    public func parse(_ request: ParseRequest) async -> DecodedResult? {
        guard request.kind == .manufacturerData, request.companyID == Self.appleCompany else {
            return nil
        }
        let data = [UInt8](request.payload)
        // [type, length, uuid(16), major(2 BE), minor(2 BE), rssi(1)]
        guard data.count == 23, data[0] == Self.iBeaconType, data[1] == Self.iBeaconLength else {
            return nil
        }

        let uuidTuple = (data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9],
                         data[10], data[11], data[12], data[13], data[14], data[15], data[16], data[17])
        let uuid = UUID(uuid: uuidTuple)
        let major = (UInt16(data[18]) << 8) | UInt16(data[19])
        let minor = (UInt16(data[20]) << 8) | UInt16(data[21])
        let rssi = Int8(bitPattern: data[22])

        return DecodedResult(
            pluginID: id,
            title: "iBeacon",
            fields: [
                DecodedField(key: "uuid", label: "Proximity UUID", value: .uuid(uuid)),
                DecodedField(key: "major", label: "Major", value: .uint(UInt64(major))),
                DecodedField(key: "minor", label: "Minor", value: .uint(UInt64(minor))),
                DecodedField(key: "tx_power", label: "Measured Power", value: .int(Int64(rssi)), unit: "dBm")
            ]
        )
    }
}

// MARK: - Well-known characteristics

/// Decodes a small set of standard GATT characteristics that carry a trivial representation
/// (battery level percentage and the Device Information string characteristics).
public struct NativeWellKnownCharacteristicParser: ParserPlugin {

    public let id = PluginID("org.pureswift.native.wellknown")
    public let name = "Well-Known Characteristics"

    // 16-bit assigned numbers, used directly so no build-time-generated constants are required.
    private static let batteryLevel = BluetoothUUID.bit16(0x2A19)
    private static let stringCharacteristics: [(uuid: BluetoothUUID, label: String)] = [
        (.bit16(0x2A00), "Device Name"),
        (.bit16(0x2A29), "Manufacturer Name"),
        (.bit16(0x2A24), "Model Number"),
        (.bit16(0x2A25), "Serial Number"),
        (.bit16(0x2A26), "Firmware Revision"),
        (.bit16(0x2A27), "Hardware Revision"),
        (.bit16(0x2A28), "Software Revision")
    ]

    public init() {}

    public var routingKeys: RoutingKeys {
        RoutingKeys(characteristicUUIDs: [Self.batteryLevel] + Self.stringCharacteristics.map(\.uuid))
    }

    public func parse(_ request: ParseRequest) async -> DecodedResult? {
        guard request.kind == .characteristic, let uuid = request.uuid else { return nil }
        guard request.payload.isEmpty == false else { return nil }

        if uuid == Self.batteryLevel {
            guard let level = request.payload.first else { return nil }
            return DecodedResult(
                pluginID: id,
                title: "Battery Level",
                fields: [DecodedField(key: "level", label: "Battery Level", value: .uint(UInt64(level)), unit: "%")]
            )
        }

        if let match = Self.stringCharacteristics.first(where: { $0.uuid == uuid }) {
            guard let string = String(data: request.payload, encoding: .utf8) else { return nil }
            return DecodedResult(
                pluginID: id,
                title: match.label,
                fields: [DecodedField(key: "value", label: match.label, value: .string(string))]
            )
        }

        return nil
    }
}
