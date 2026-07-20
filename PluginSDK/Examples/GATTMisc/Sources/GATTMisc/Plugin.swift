//
//  Plugin.swift
//  GATTMisc
//
//  Assorted GATT characteristics, ported from BluetoothGATT.
//
//  0x2AA3 Barometric Pressure Trend
//  0x2AAB CGM Session Run Time
//  0x2B88 Encrypted Data Key Material
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2AA3: return barometricPressureTrend(input)
    case 0x2AAB: return cgmSessionRunTime(input)
    case 0x2B88: return encryptedDataKeyMaterial(input)
    default: return nil
    }
}

/// Barometric Pressure Trend (0x2AA3): a single byte enum. Unknown raw values are rejected,
/// matching `GATTBarometricPressureTrend.init?(data:)`.
private func barometricPressureTrend(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let rawValue = payload.readUInt8() else { return nil }

    let name: StaticString
    switch rawValue {
    case 0x00: name = "unknown"
    case 0x01: name = "continuouslyFalling"
    case 0x02: name = "continuouslyRising"
    case 0x03: name = "fallingThenSteady"
    case 0x04: name = "risingThenSteady"
    case 0x05: name = "fallingBeforeLesserRise"
    case 0x06: name = "fallingBeforeGreaterRise"
    case 0x07: name = "risingBeforeGreaterFall"
    case 0x08: name = "risingBeforeLesserFall"
    case 0x09: name = "steady"
    default: return nil
    }

    var fields = Fields(summary: "Barometric Pressure Trend")
    fields.string("trend", label: "Trend", name)
    fields.uint("raw_value", label: "Raw Value", UInt64(rawValue))
    return fields
}

/// CGM Session Run Time (0x2AAB): a 16-bit run time in hours, little-endian, optionally
/// followed by a 16-bit E2E-CRC when the value is exactly 4 octets long.
private func cgmSessionRunTime(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    let count = payload.remaining
    guard count >= 2, let sessionRunTime = payload.readUInt16LittleEndian() else { return nil }

    var fields = Fields(summary: "CGM Session Run Time")
    fields.uint("session_run_time", label: "Session Run Time", UInt64(sessionRunTime), unit: "hours")
    if count == 4, let e2ecrc = payload.readUInt16LittleEndian() {
        fields.uint("e2e_crc", label: "E2E-CRC", UInt64(e2ecrc))
    }
    return fields
}

/// Encrypted Data Key Material (0x2B88): a 16-octet session key followed by an 8-octet
/// initialization vector, for a total of exactly 24 octets.
private func encryptedDataKeyMaterial(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 24 else { return nil }

    var fields = Fields(summary: "Encrypted Data Key Material")
    guard payload.readBytes(16, { buffer in
        fields.bytes("session_key", label: "Session Key", buffer)
    }) != nil else { return nil }
    guard payload.readBytes(8, { buffer in
        fields.bytes("initialization_vector", label: "Initialization Vector", buffer)
    }) != nil else { return nil }
    return fields
}
