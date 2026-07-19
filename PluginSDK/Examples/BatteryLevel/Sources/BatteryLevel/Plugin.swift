//
//  Plugin.swift
//  BatteryLevel
//
//  The only file a plugin author writes: a pure function from ParseInput to Fields.
//  Decodes the GATT Battery Level characteristic (0x2A19), a single percentage byte.
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    // Routing already guarantees 0x2A19, but check so the plugin is correct standalone.
    guard input.uuid?.assignedNumber16 == 0x2A19 else { return nil }

    var payload = input.payload
    guard let level = payload.readUInt8() else { return nil }

    var fields = Fields(summary: "Battery")
    fields.uint("level", label: "Battery Level", UInt64(level), unit: "%")
    return fields
}
