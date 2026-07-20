//
//  Plugin.swift
//  GATTBattery
//
//  Battery service characteristics, ported from BluetoothGATT.
//
//  0x2A19 Battery Level          0x2BF0 Battery Power State
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A19: return batteryLevel(input)
    case 0x2BF0: return batteryPowerState(input)
    default: return nil
    }
}

/// Battery Level (0x2A19): a single byte percentage, 0...100 inclusive.
/// `GATTBatteryPercentage(rawValue:)` rejects anything above 100.
private func batteryLevel(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1,
          let level = payload.readUInt8(),
          level <= 100
    else { return nil }

    var fields = Fields(summary: "Battery Level")
    fields.uint("battery_level", label: "Battery Level", UInt64(level), unit: "%")
    return fields
}

/// Battery Power State (0x2BF0): a single byte carrying four 2-bit enums,
/// most significant pair first: present, discharge, charge, level.
private func batteryPowerState(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let byte = payload.readUInt8() else { return nil }

    let present = (byte >> 6) & 0b11
    let discharge = (byte >> 4) & 0b11
    let charge = (byte >> 2) & 0b11
    let level = byte & 0b11
    // Every 2-bit value maps to a defined case in BluetoothGATT, so no value is rejected here.

    var fields = Fields(summary: "Battery Power State")

    let presentName: StaticString
    switch present {
    case 0x00: presentName = "Unknown"
    case 0x01: presentName = "Not Supported"
    case 0x02: presentName = "Not Present"
    default: presentName = "Present"
    }
    fields.string("present_state", label: "Present State", presentName)

    let dischargeName: StaticString
    switch discharge {
    case 0x00: dischargeName = "Unknown"
    case 0x01: dischargeName = "Not Supported"
    case 0x02: dischargeName = "Not Discharging"
    default: dischargeName = "Discharging"
    }
    fields.string("discharge_state", label: "Discharge State", dischargeName)

    let chargeName: StaticString
    switch charge {
    case 0x00: chargeName = "Unknown"
    case 0x01: chargeName = "Not Chargeable"
    case 0x02: chargeName = "Not Charging"
    default: chargeName = "Charging"
    }
    fields.string("charge_state", label: "Charge State", chargeName)

    let levelName: StaticString
    switch level {
    case 0x00: levelName = "Unknown"
    case 0x01: levelName = "Not Supported"
    case 0x02: levelName = "Good Level"
    default: levelName = "Critically Low Level"
    }
    fields.string("level_state", label: "Level State", levelName)

    return fields
}
