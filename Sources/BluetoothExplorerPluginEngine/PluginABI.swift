//
//  PluginABI.swift
//  BluetoothExplorerPluginEngine
//
//  Normative constants and encoding helpers for BLE parser plugin ABI v1.
//  See Documentation/WasmPluginPlan.md §4.
//

import Foundation
import Bluetooth

/// ABI v1 constants and the host<->guest wire format.
public enum PluginABI {

    /// ABI major version implemented by this host.
    public static let version = 1

    /// Envelope format version written into every input envelope.
    public static let envelopeVersion: UInt8 = 1

    // MARK: Export names

    /// Marker export whose presence declares ABI major version 1.
    public static let markerExport = "bleplug_abi_1"
    /// Guest allocator: `(size: i32) -> i32`.
    public static let allocExport = "bleplug_alloc"
    /// Exported linear memory.
    public static let memoryExport = "memory"
    /// Optional guest deallocator: `(ptr: i32, size: i32) -> ()`.
    public static let freeExport = "bleplug_free"
    /// Optional arena reset: `() -> ()`.
    public static let resetExport = "bleplug_reset"
    /// Optional wasip1 reactor init: `() -> ()`.
    public static let initializeExport = "_initialize"

    /// The parse entry points; presence of an export declares that capability.
    public static func parseExport(for kind: ParseKind) -> String {
        switch kind {
        case .manufacturerData: return "bleplug_parse_manufacturer"
        case .serviceData: return "bleplug_parse_service_data"
        case .characteristic: return "bleplug_parse_characteristic"
        case .descriptor: return "bleplug_parse_descriptor"
        }
    }

    /// Default cap on a decoded output buffer, in bytes.
    public static let defaultMaxOutputBytes = 16 * 1024

    /// Absolute ceiling on guest linear memory, in 64 KiB pages, regardless of manifest.
    public static let maxMemoryPagesCeiling = 64

    /// Default guest linear-memory cap, in pages, when the manifest does not specify one.
    public static let defaultMaxMemoryPages = 16
}

/// The kind of data being parsed. Also the `kind` byte in the input envelope.
public enum ParseKind: UInt8, Equatable, Hashable, Sendable, CaseIterable {
    case manufacturerData = 1
    case serviceData = 2
    case characteristic = 3
    case descriptor = 4
}

// MARK: - Envelope encoding

extension PluginABI {

    /// Fixed header size preceding the payload in the input envelope.
    static let envelopeHeaderSize = 24

    /// Encode an input envelope for a guest parse call.
    ///
    /// Layout (little-endian scalars; UUID is RFC-4122 big-endian):
    /// ```
    /// 0  u8    envelope_version (= 1)
    /// 1  u8    kind
    /// 2  u16   company_id (0xFFFF unless kind == manufacturerData)
    /// 4  [16]  uuid (zeroed when kind == manufacturerData)
    /// 20 u32   payload_len
    /// 24 ...   payload
    /// ```
    public static func encodeEnvelope(
        kind: ParseKind,
        companyID: UInt16?,
        uuid: BluetoothUUID?,
        payload: Data
    ) -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(envelopeHeaderSize + payload.count)
        bytes.append(envelopeVersion)
        bytes.append(kind.rawValue)

        let company = companyID ?? 0xFFFF
        bytes.append(UInt8(company & 0xFF))
        bytes.append(UInt8((company >> 8) & 0xFF))

        bytes.append(contentsOf: uuid.map(uuidBigEndianBytes) ?? [UInt8](repeating: 0, count: 16))

        let length = UInt32(payload.count)
        bytes.append(UInt8(length & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8((length >> 16) & 0xFF))
        bytes.append(UInt8((length >> 24) & 0xFF))

        bytes.append(contentsOf: payload)
        return bytes
    }

    /// A `BluetoothUUID` as 16 RFC-4122 big-endian bytes, promoting 16/32-bit UUIDs via the
    /// Bluetooth base UUID.
    static func uuidBigEndianBytes(_ uuid: BluetoothUUID) -> [UInt8] {
        // Promote to the 128-bit form; UUID.uuid is RFC-4122 big-endian bytes.
        let uuid128 = UUID(bluetooth: uuid)
        let t = uuid128.uuid
        return [t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7,
                t.8, t.9, t.10, t.11, t.12, t.13, t.14, t.15]
    }

    /// Unpack a guest parse return value into `(pointer, length)`.
    /// `0` signals "no result / not mine".
    public static func unpackResult(_ packed: UInt64) -> (pointer: UInt32, length: UInt32)? {
        guard packed != 0 else { return nil }
        let pointer = UInt32(packed >> 32)
        let length = UInt32(packed & 0xFFFF_FFFF)
        return (pointer, length)
    }
}
