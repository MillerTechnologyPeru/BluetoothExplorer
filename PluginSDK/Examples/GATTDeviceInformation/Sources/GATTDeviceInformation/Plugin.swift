//
//  Plugin.swift
//  GATTDeviceInformation
//
//  Device Information service characteristics, ported from BluetoothGATT.
//
//  0x2A23 System ID                 0x2A27 Hardware Revision String
//  0x2A24 Model Number String       0x2A28 Software Revision String
//  0x2A25 Serial Number String      0x2A29 Manufacturer Name String
//  0x2A26 Firmware Revision String  0x2A50 PnP ID
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A24: return utf8String(input, summary: "Model Number", key: "model_number", label: "Model Number")
    case 0x2A25: return utf8String(input, summary: "Serial Number", key: "serial_number", label: "Serial Number")
    case 0x2A26: return utf8String(input, summary: "Firmware Revision", key: "firmware_revision", label: "Firmware Revision")
    case 0x2A27: return utf8String(input, summary: "Hardware Revision", key: "hardware_revision", label: "Hardware Revision")
    case 0x2A28: return utf8String(input, summary: "Software Revision", key: "software_revision", label: "Software Revision")
    case 0x2A29: return utf8String(input, summary: "Manufacturer Name", key: "manufacturer_name", label: "Manufacturer Name")
    case 0x2A23: return systemID(input)
    case 0x2A50: return pnpID(input)
    default: return nil
    }
}

/// A characteristic whose whole value is a UTF-8 string.
///
/// An empty value is valid: BluetoothGATT decodes these with `String(utf8:)`, which accepts an
/// empty byte sequence, so rejecting it here would make the plugin stricter than the library.
private func utf8String(
    _ input: ParseInput, summary: StaticString, key: StaticString, label: StaticString
) -> Fields? {
    var payload = input.payload
    var fields = Fields(summary: summary)
    payload.remainingBytes { buffer in
        fields.text(key, label: label, utf8: buffer)
    }
    return fields
}

/// System ID (0x2A23): a 64-bit value split into a 40-bit manufacturer identifier and a
/// 24-bit organizationally unique identifier, little-endian.
private func systemID(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 8 else { return nil }
    var raw: UInt64 = 0
    for index in 0..<8 {
        guard let byte = payload.readUInt8() else { return nil }
        raw |= UInt64(byte) << (8 * UInt64(index))
    }
    var fields = Fields(summary: "System ID")
    fields.uint("manufacturer_identifier", label: "Manufacturer Identifier", raw & 0xFF_FFFF_FFFF)
    fields.uint("organizationally_unique_identifier", label: "Organizationally Unique Identifier", raw >> 40)
    return fields
}

/// PnP ID (0x2A50): vendor id source, vendor id, product id, product version.
private func pnpID(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 7,
          let source = payload.readUInt8(),
          let vendor = payload.readUInt16LittleEndian(),
          let product = payload.readUInt16LittleEndian(),
          let version = payload.readUInt16LittleEndian()
    else { return nil }
    // BluetoothGATT rejects unknown vendor id sources, so match that behaviour.
    guard source == 1 || source == 2 else { return nil }

    var fields = Fields(summary: "PnP ID")
    fields.string(
        "vendor_id_source", label: "Vendor ID Source",
        source == 1 ? "Bluetooth SIG" : "USB Implementer's Forum"
    )
    fields.uint("vendor_id", label: "Vendor ID", UInt64(vendor))
    fields.uint("product_id", label: "Product ID", UInt64(product))
    fields.uint("product_version", label: "Product Version", UInt64(version))
    return fields
}
