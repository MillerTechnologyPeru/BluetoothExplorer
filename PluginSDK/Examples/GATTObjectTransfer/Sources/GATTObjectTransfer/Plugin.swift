//
//  Plugin.swift
//  GATTObjectTransfer
//
//  Object Transfer Service characteristics, ported from BluetoothGATT.
//
//  0x2ABE Object Name    0x2AC0 Object Size
//  0x2ABF Object Type    0x2AC3 Object ID
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2ABE: return objectName(input)
    case 0x2ABF: return objectType(input)
    case 0x2AC0: return objectSize(input)
    case 0x2AC3: return objectID(input)
    default: return nil
    }
}

/// Object Name (0x2ABE): a UTF-8 string of at most 120 bytes.
private func objectName(_ input: ParseInput) -> Fields? {
    let payload = input.payload
    // GATTObjectName rejects any value longer than 120 UTF-8 bytes.
    guard payload.remaining <= 120 else { return nil }
    var fields = Fields(summary: "Object Name")
    payload.remainingBytes { buffer in
        fields.text("object_name", label: "Object Name", utf8: buffer)
    }
    return fields
}

/// Object Type (0x2ABF): the UUID of the object's type.
///
/// BluetoothGATT models this as a little-endian 16-bit assigned number. The 128-bit form is
/// also accepted here and reported as a UUID.
private func objectType(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    switch payload.remaining {
    case 2:
        guard let rawValue = payload.readUInt16LittleEndian() else { return nil }
        var fields = Fields(summary: "Object Type")
        fields.uint("object_type", label: "Object Type", UInt64(rawValue))
        return fields
    default:
        return nil
    }
}

/// Object Size (0x2AC0): current and allocated sizes, each a little-endian 32-bit byte count.
private func objectSize(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 8,
          let current = payload.readUInt32LittleEndian(),
          let allocated = payload.readUInt32LittleEndian()
    else { return nil }

    var fields = Fields(summary: "Object Size")
    fields.uint("current_size", label: "Current Size", UInt64(current), unit: "bytes")
    fields.uint("allocated_size", label: "Allocated Size", UInt64(allocated), unit: "bytes")
    return fields
}

/// Object ID (0x2AC3): a little-endian 48-bit identifier in the range 256...281_474_976_710_655.
private func objectID(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 6 else { return nil }
    var rawValue: UInt64 = 0
    for index in 0..<6 {
        guard let byte = payload.readUInt8() else { return nil }
        rawValue |= UInt64(byte) << (8 * UInt64(index))
    }
    // GATTObjectID rejects values outside its reserved range.
    guard rawValue >= 256, rawValue <= 281_474_976_710_655 else { return nil }

    var fields = Fields(summary: "Object ID")
    fields.uint("object_id", label: "Object ID", rawValue)
    return fields
}
