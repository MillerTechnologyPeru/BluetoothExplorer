//
//  Plugin.swift
//  GATTGenericService
//
//  Generic Access / Generic Attribute service characteristics, ported from BluetoothGATT.
//
//  0x2A05 Service Changed              0x2B29 Client Supported Features
//  0x2A31 Scan Refresh                 0x2B2A Database Hash
//  0x2A4F Scan Interval Window         0x2BF5 LE GATT Security Levels
//  0x2AA6 Central Address Resolution
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A05: return serviceChanged(input)
    case 0x2A31: return scanRefresh(input)
    case 0x2A4F: return scanIntervalWindow(input)
    case 0x2AA6: return centralAddressResolution(input)
    case 0x2B29: return clientSupportedFeatures(input)
    case 0x2B2A: return databaseHash(input)
    case 0x2BF5: return leSecurityLevels(input)
    default: return nil
    }
}

/// Service Changed (0x2A05): two little-endian 16-bit attribute handles.
private func serviceChanged(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 4,
          let start = payload.readUInt16LittleEndian(),
          let end = payload.readUInt16LittleEndian()
    else { return nil }

    var fields = Fields(summary: "Service Changed")
    fields.uint("start_handle", label: "Start Handle", UInt64(start))
    fields.uint("end_handle", label: "End Handle", UInt64(end))
    return fields
}

/// Scan Refresh (0x2A31): a single byte enum; only `0` is defined.
private func scanRefresh(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let rawValue = payload.readUInt8() else { return nil }
    // BluetoothGATT rejects raw values without a matching case.
    guard rawValue == 0 else { return nil }

    var fields = Fields(summary: "Scan Refresh")
    fields.string("scan_refresh", label: "Scan Refresh", "Server Required Refresh")
    return fields
}

/// Scan Interval Window (0x2A4F): two little-endian LE scan time intervals.
/// Each must be within 0x0004...0x4000; Time = N * 0.625 msec.
private func scanIntervalWindow(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 4,
          let interval = payload.readUInt16LittleEndian(),
          let window = payload.readUInt16LittleEndian()
    else { return nil }
    guard interval >= 0x0004, interval <= 0x4000 else { return nil }
    guard window >= 0x0004, window <= 0x4000 else { return nil }

    var fields = Fields(summary: "Scan Interval Window")
    fields.double("scan_interval", label: "Scan Interval", Double(interval) * 0.625, unit: "ms")
    fields.double("scan_window", label: "Scan Window", Double(window) * 0.625, unit: "ms")
    return fields
}

/// Central Address Resolution (0x2AA6): a single boolean byte, only `0` or `1`.
private func centralAddressResolution(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let rawValue = payload.readUInt8() else { return nil }
    guard rawValue == 0x00 || rawValue == 0x01 else { return nil }

    var fields = Fields(summary: "Central Address Resolution")
    fields.bool("is_supported", label: "Address Resolution Supported", rawValue == 0x01)
    return fields
}

/// Client Supported Features (0x2B29): a variable-length little-endian bit field.
///
/// BluetoothGATT decodes 8, 4, 2 or 1 leading bytes depending on the value's length,
/// and rejects an empty value.
private func clientSupportedFeatures(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    let count = payload.remaining
    let byteCount: Int
    if count == 8 {
        byteCount = 8
    } else if count >= 4 {
        byteCount = 4
    } else if count >= 2 {
        byteCount = 2
    } else if count >= 1 {
        byteCount = 1
    } else {
        return nil
    }

    var bitmask: UInt64 = 0
    for index in 0..<byteCount {
        guard let byte = payload.readUInt8() else { return nil }
        bitmask |= UInt64(byte) << (8 * UInt64(index))
    }

    var fields = Fields(summary: "Client Supported Features")
    fields.bool("robust_caching", label: "Robust Caching", bitmask & 0b001 != 0)
    fields.bool("enhanced_att", label: "Enhanced ATT Bearer", bitmask & 0b010 != 0)
    fields.bool(
        "multiple_handle_value_notifications",
        label: "Multiple Handle Value Notifications",
        bitmask & 0b100 != 0
    )
    return fields
}

/// Database Hash (0x2B2A): a 128-bit AES-CMAC hash, exactly 16 bytes.
private func databaseHash(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 16 else { return nil }
    var fields = Fields(summary: "Database Hash")
    payload.readBytes(16) { buffer in
        fields.bytes("hash", label: "Database Hash", buffer)
    }
    return fields
}

/// LE GATT Security Levels (0x2BF5): one or more 2-byte Security Level Requirements fields,
/// each a security mode followed by a security level.
private func leSecurityLevels(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    let count = payload.remaining
    guard count >= 2, count % 2 == 0 else { return nil }

    var fields = Fields(summary: "LE GATT Security Levels")
    fields.uint("requirement_count", label: "Requirement Count", UInt64(count / 2))

    var index = 0
    while index < count / 2 {
        guard let mode = payload.readUInt8(), let level = payload.readUInt8() else { return nil }
        switch index {
        case 0:
            fields.uint("requirement_1_mode", label: "Requirement 1 Security Mode", UInt64(mode))
            fields.uint("requirement_1_level", label: "Requirement 1 Security Level", UInt64(level))
        case 1:
            fields.uint("requirement_2_mode", label: "Requirement 2 Security Mode", UInt64(mode))
            fields.uint("requirement_2_level", label: "Requirement 2 Security Level", UInt64(level))
        case 2:
            fields.uint("requirement_3_mode", label: "Requirement 3 Security Mode", UInt64(mode))
            fields.uint("requirement_3_level", label: "Requirement 3 Security Level", UInt64(level))
        case 3:
            fields.uint("requirement_4_mode", label: "Requirement 4 Security Mode", UInt64(mode))
            fields.uint("requirement_4_level", label: "Requirement 4 Security Level", UInt64(level))
        default:
            break
        }
        index += 1
    }
    return fields
}
