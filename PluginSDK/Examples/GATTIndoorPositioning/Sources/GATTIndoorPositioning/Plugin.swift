//
//  Plugin.swift
//  GATTIndoorPositioning
//
//  Indoor Positioning service characteristics, ported from BluetoothGATT.
//
//  0x2AAD Indoor Positioning Configuration  0x2AB1 Local East Coordinate
//  0x2AAE Latitude                          0x2AB2 Floor Number
//  0x2AAF Longitude                         0x2AB3 Altitude
//  0x2AB0 Local North Coordinate            0x2AB4 Uncertainty
//                                           0x2AB5 Location Name
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2AAD: return indoorPositioningConfiguration(input)
    case 0x2AAE: return latitude(input)
    case 0x2AAF: return longitude(input)
    case 0x2AB0: return localNorthCoordinate(input)
    case 0x2AB1: return localEastCoordinate(input)
    case 0x2AB2: return floorNumber(input)
    case 0x2AB3: return altitude(input)
    case 0x2AB4: return uncertainty(input)
    case 0x2AB5: return locationName(input)
    default: return nil
    }
}

/// Indoor Positioning Configuration (0x2AAD): a one byte bit mask describing which values are
/// present in the Indoor Positioning Service AD type.
private func indoorPositioningConfiguration(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let raw = payload.readUInt8() else { return nil }

    var fields = Fields(summary: "Indoor Positioning Configuration")
    fields.bool("coordinates", label: "Coordinates", raw & 0b01 != 0)
    fields.bool("coordinate_system_used", label: "Coordinate System Used", raw & 0b10 != 0)
    fields.bool("tx_power_field", label: "Tx Power Field", raw & 0b100 != 0)
    fields.bool("altitude_field", label: "Altitude Field", raw & 0b1000 != 0)
    fields.bool("floor_number", label: "Floor Number", raw & 0b10000 != 0)
    fields.bool("location_name", label: "Location Name", raw & 0b100000 != 0)
    return fields
}

/// Latitude (0x2AAE): WGS84 North coordinate, signed 32-bit little-endian, 1e-7 degrees.
private func latitude(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 4, let raw = payload.readUInt32LittleEndian() else { return nil }
    let value = Int32(bitPattern: raw)

    var fields = Fields(summary: "Latitude")
    fields.int("latitude", label: "Latitude", Int64(value))
    fields.double("latitude_degrees", label: "Latitude", Double(value) * 1e-7, unit: "°")
    return fields
}

/// Longitude (0x2AAF): WGS84 East coordinate, signed 32-bit little-endian, 1e-7 degrees.
private func longitude(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 4, let raw = payload.readUInt32LittleEndian() else { return nil }
    let value = Int32(bitPattern: raw)

    var fields = Fields(summary: "Longitude")
    fields.int("longitude", label: "Longitude", Int64(value))
    fields.double("longitude_degrees", label: "Longitude", Double(value) * 1e-7, unit: "°")
    return fields
}

/// Local North Coordinate (0x2AB0): signed 16-bit little-endian, decimetres.
private func localNorthCoordinate(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2, let raw = payload.readUInt16LittleEndian() else { return nil }
    let value = Int16(bitPattern: raw)

    var fields = Fields(summary: "Local North Coordinate")
    fields.int("local_north_coordinate", label: "Local North Coordinate", Int64(value))
    fields.double("local_north_metres", label: "Local North", Double(value) * 0.1, unit: "m")
    return fields
}

/// Local East Coordinate (0x2AB1): signed 16-bit little-endian, decimetres.
private func localEastCoordinate(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2, let raw = payload.readUInt16LittleEndian() else { return nil }
    let value = Int16(bitPattern: raw)

    var fields = Fields(summary: "Local East Coordinate")
    fields.int("local_east_coordinate", label: "Local East Coordinate", Int64(value))
    fields.double("local_east_metres", label: "Local East", Double(value) * 0.1, unit: "m")
    return fields
}

/// Floor Number (0x2AB2): a single unsigned byte.
private func floorNumber(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let raw = payload.readUInt8() else { return nil }

    var fields = Fields(summary: "Floor Number")
    fields.uint("floor_number", label: "Floor Number", UInt64(raw))
    return fields
}

/// Altitude (0x2AB3): unsigned 16-bit little-endian, metres.
private func altitude(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2, let raw = payload.readUInt16LittleEndian() else { return nil }

    var fields = Fields(summary: "Altitude")
    fields.uint("altitude", label: "Altitude", UInt64(raw), unit: "m")
    return fields
}

/// Uncertainty (0x2AB4): one byte packing stationary (bit 0), update time (bits 1-3) and
/// precision (bits 4-6). BluetoothGATT rejects raw values outside the defined enums.
private func uncertainty(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let raw = payload.readUInt8() else { return nil }

    let stationaryRaw = raw & 0b0000_0001
    let updateTimeRaw = (raw & 0b0000_1110) >> 1
    let precisionRaw = (raw & 0b0111_0000) >> 4

    let stationary: StaticString
    switch stationaryRaw {
    case 0x00: stationary = "stationary"
    case 0x01: stationary = "mobile"
    default: return nil
    }

    let updateTime: StaticString
    switch updateTimeRaw {
    case 0x00: updateTime = "upTo3s"
    case 0x01: updateTime = "upTo4s"
    case 0x02: updateTime = "upTo6s"
    case 0x03: updateTime = "upTo12s"
    case 0x04: updateTime = "upTo28s"
    case 0x05: updateTime = "upTo89s"
    case 0x06: updateTime = "upTo426s"
    case 0x07: updateTime = "upTo3541s"
    default: return nil
    }

    let precision: StaticString
    switch precisionRaw {
    case 0x00: precision = "lessThan10cm"
    case 0x01: precision = "between10cmTo1m"
    case 0x02: precision = "between1mTo2m"
    case 0x03: precision = "between2mTo5m"
    case 0x04: precision = "between5mTo10m"
    case 0x05: precision = "between10mTo50m"
    case 0x06: precision = "greaterThen50m"
    case 0x07: precision = "unknown"
    default: return nil
    }

    var fields = Fields(summary: "Uncertainty")
    fields.string("stationary", label: "Stationary", stationary)
    fields.string("update_time", label: "Update Time", updateTime)
    fields.string("precision", label: "Precision", precision)
    return fields
}

/// Location Name (0x2AB5): the whole value is a UTF-8 string.
private func locationName(_ input: ParseInput) -> Fields? {
    let payload = input.payload
    // BluetoothGATT builds the value with `String(utf8:)`, which rejects invalid UTF-8.
    guard payload.remainingBytes({ isValidUTF8($0) }) else { return nil }

    var fields = Fields(summary: "Location Name")
    payload.remainingBytes { buffer in
        fields.text("location_name", label: "Location Name", utf8: buffer)
    }
    return fields
}

/// Whether `buffer` is a well-formed UTF-8 sequence.
private func isValidUTF8(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
    var index = 0
    let count = buffer.count
    while index < count {
        let byte = buffer[index]
        var continuations = 0
        var lowerBound: UInt32 = 0
        var scalar: UInt32 = 0
        if byte < 0x80 {
            index += 1
            continue
        } else if byte & 0xE0 == 0xC0 {
            continuations = 1
            lowerBound = 0x80
            scalar = UInt32(byte & 0x1F)
        } else if byte & 0xF0 == 0xE0 {
            continuations = 2
            lowerBound = 0x800
            scalar = UInt32(byte & 0x0F)
        } else if byte & 0xF8 == 0xF0 {
            continuations = 3
            lowerBound = 0x1_0000
            scalar = UInt32(byte & 0x07)
        } else {
            return false
        }
        guard index + continuations < count else { return false }
        for offset in 1...continuations {
            let next = buffer[index + offset]
            guard next & 0xC0 == 0x80 else { return false }
            scalar = (scalar << 6) | UInt32(next & 0x3F)
        }
        // Reject overlong encodings, surrogates and out-of-range scalars.
        guard scalar >= lowerBound, scalar <= 0x10_FFFF,
              scalar < 0xD800 || scalar > 0xDFFF
        else { return false }
        index += continuations + 1
    }
    return true
}
