//
//  Plugin.swift
//  GATTHID
//
//  HID service boot protocol report characteristics, ported from BluetoothGATT.
//
//  0x2A22 Boot Keyboard Input Report
//  0x2A32 Boot Keyboard Output Report
//  0x2A33 Boot Mouse Input Report
//
//  All three types in BluetoothGATT are `RawRepresentable` wrappers over a single `UInt8`
//  whose `init?(data:)` requires `data.count == MemoryLayout<UInt8>.size`. They perform no
//  further HID report decoding, so neither does this plugin.
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A22: return bootKeyboardInputReport(input)
    case 0x2A32: return bootKeyboardOutputReport(input)
    case 0x2A33: return bootMouseInputReport(input)
    default: return nil
    }
}

/// Boot Keyboard Input Report (0x2A22): a single raw report byte.
private func bootKeyboardInputReport(_ input: ParseInput) -> Fields? {
    report(
        input,
        summary: "Boot Keyboard Input Report",
        key: "boot_keyboard_input_report",
        label: "Boot Keyboard Input Report"
    )
}

/// Boot Keyboard Output Report (0x2A32): a single raw report byte.
private func bootKeyboardOutputReport(_ input: ParseInput) -> Fields? {
    report(
        input,
        summary: "Boot Keyboard Output Report",
        key: "boot_keyboard_output_report",
        label: "Boot Keyboard Output Report"
    )
}

/// Boot Mouse Input Report (0x2A33): a single raw report byte.
private func bootMouseInputReport(_ input: ParseInput) -> Fields? {
    report(
        input,
        summary: "Boot Mouse Input Report",
        key: "boot_mouse_input_report",
        label: "Boot Mouse Input Report"
    )
}

/// The shared shape of all three boot protocol reports: exactly one byte of raw report data.
///
/// Mirrors `init?<Data: DataContainer>(data:)`, which returns nil unless
/// `data.count == MemoryLayout<UInt8>.size`, then stores `data[0]` as `rawValue`.
private func report(
    _ input: ParseInput, summary: StaticString, key: StaticString, label: StaticString
) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }

    var fields = Fields(summary: summary)
    // The raw report byte, then the same byte as a number for readability.
    guard let rawValue = payload.readBytes(1, { buffer -> UInt8 in
        fields.bytes(key, label: label, buffer)
        return buffer[0]
    }) else { return nil }
    fields.uint("report_value", label: "Report Value", UInt64(rawValue))
    fields.uint("report_length", label: "Report Length", 1, unit: "bytes")
    return fields
}
