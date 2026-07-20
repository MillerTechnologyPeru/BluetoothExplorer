//
//  Plugin.swift
//  GATTUserData
//
//  User Data service characteristics, ported from BluetoothGATT.
//
//  0x2A7E Aerobic Heart Rate Lower Limit    0x2A81 Anaerobic Heart Rate Lower Limit
//  0x2A7F Aerobic Threshold                 0x2A82 Anaerobic Heart Rate Upper Limit
//  0x2A80 Age                               0x2A84 Aerobic Heart Rate Upper Limit
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A7E: return aerobicHeartRateLowerLimit(input)
    case 0x2A7F: return aerobicThreshold(input)
    case 0x2A80: return age(input)
    case 0x2A81: return anaerobicHeartRateLowerLimit(input)
    case 0x2A82: return anaerobicHeartRateUpperLimit(input)
    case 0x2A84: return aerobicHeartRateUpperLimit(input)
    default: return nil
    }
}

/// A characteristic whose whole value is a single unsigned byte with a unit.
private func singleByte(
    _ input: ParseInput,
    summary: StaticString, key: StaticString, label: StaticString, unit: StaticString
) -> Fields? {
    var payload = input.payload
    // BluetoothGATT requires `data.count == MemoryLayout<UInt8>.size`.
    guard payload.remaining == 1, let value = payload.readUInt8() else { return nil }
    var fields = Fields(summary: summary)
    fields.uint(key, label: label, UInt64(value), unit: unit)
    return fields
}

/// Aerobic Heart Rate Lower Limit (0x2A7E): beats per minute, 1 byte.
private func aerobicHeartRateLowerLimit(_ input: ParseInput) -> Fields? {
    singleByte(
        input, summary: "Aerobic Heart Rate Lower Limit",
        key: "aerobic_heart_rate_lower_limit", label: "Aerobic Heart Rate Lower Limit", unit: "bpm"
    )
}

/// Aerobic Threshold (0x2A7F): first metabolic threshold, beats per minute, 1 byte.
private func aerobicThreshold(_ input: ParseInput) -> Fields? {
    singleByte(
        input, summary: "Aerobic Threshold",
        key: "aerobic_threshold", label: "Aerobic Threshold", unit: "bpm"
    )
}

/// Age (0x2A80): age of the user in years, 1 byte.
private func age(_ input: ParseInput) -> Fields? {
    singleByte(input, summary: "Age", key: "age", label: "Age", unit: "years")
}

/// Anaerobic Heart Rate Lower Limit (0x2A81): beats per minute, 1 byte.
private func anaerobicHeartRateLowerLimit(_ input: ParseInput) -> Fields? {
    singleByte(
        input, summary: "Anaerobic Heart Rate Lower Limit",
        key: "anaerobic_heart_rate_lower_limit", label: "Anaerobic Heart Rate Lower Limit", unit: "bpm"
    )
}

/// Anaerobic Heart Rate Upper Limit (0x2A82): beats per minute, 1 byte.
private func anaerobicHeartRateUpperLimit(_ input: ParseInput) -> Fields? {
    singleByte(
        input, summary: "Anaerobic Heart Rate Upper Limit",
        key: "anaerobic_heart_rate_upper_limit", label: "Anaerobic Heart Rate Upper Limit", unit: "bpm"
    )
}

/// Aerobic Heart Rate Upper Limit (0x2A84): beats per minute, 1 byte.
private func aerobicHeartRateUpperLimit(_ input: ParseInput) -> Fields? {
    singleByte(
        input, summary: "Aerobic Heart Rate Upper Limit",
        key: "aerobic_heart_rate_upper_limit", label: "Aerobic Heart Rate Upper Limit", unit: "bpm"
    )
}
