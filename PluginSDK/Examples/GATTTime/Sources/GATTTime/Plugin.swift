//
//  Plugin.swift
//  GATTTime
//
//  Current Time / Next DST Change / Reference Time Update service characteristics,
//  ported from BluetoothGATT.
//
//  0x2A08 Date Time                  0x2A0F Local Time Information
//  0x2A09 Day of Week                0x2A11 Time with DST
//  0x2A0A Day Date Time              0x2A12 Time Accuracy
//  0x2A0C Exact Time 256             0x2A13 Time Source
//  0x2A0D DST Offset                 0x2A14 Reference Time Information
//  0x2A0E Time Zone                  0x2A16 Time Update Control Point
//  0x2A17 Time Update State          0x2A2B Current Time
//  0x2AED Date UTC
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A08: return dateTime(input)
    case 0x2A09: return dayOfWeek(input)
    case 0x2A0A: return dayDateTime(input)
    case 0x2A0C: return exactTime256(input)
    case 0x2A0D: return dstOffset(input)
    case 0x2A0E: return timeZone(input)
    case 0x2A0F: return localTimeInformation(input)
    case 0x2A11: return timeWithDst(input)
    case 0x2A12: return timeAccuracy(input)
    case 0x2A13: return timeSource(input)
    case 0x2A14: return referenceTimeInformation(input)
    case 0x2A16: return timeUpdateControlPoint(input)
    case 0x2A17: return timeUpdateState(input)
    case 0x2A2B: return currentTime(input)
    case 0x2AED: return dateUTC(input)
    default: return nil
    }
}

// MARK: - Shared Date Time

/// Reads the 7-byte Date Time structure (year u16 LE, month, day, hour, minute, second)
/// and emits its fields. Returns `false` where `GATTDateTime.init(data:)` returns nil.
private func readDateTime(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let year = payload.readUInt16LittleEndian(),
          let month = payload.readUInt8(),
          let day = payload.readUInt8(),
          let hour = payload.readUInt8(),
          let minute = payload.readUInt8(),
          let second = payload.readUInt8()
    else { return false }

    // GATTDateTime.Year: unknown (0) or 1582...9999.
    guard year == 0 || (year >= 1582 && year <= 9999) else { return false }
    // GATTDateTime.Month: 0...12.
    guard month <= 12 else { return false }
    // GATTDateTime.Day: unknown (0) or 1...31.
    guard day <= 31 else { return false }
    // Hour 0...23, Minute 0...59, Second 0...59.
    guard hour <= 23, minute <= 59, second <= 59 else { return false }

    if year == 0 {
        fields.string("year", label: "Year", "Unknown")
    } else {
        fields.uint("year", label: "Year", UInt64(year))
    }
    fields.string("month", label: "Month", monthName(month))
    if day == 0 {
        fields.string("day", label: "Day", "Unknown")
    } else {
        fields.uint("day", label: "Day", UInt64(day))
    }
    fields.uint("hour", label: "Hour", UInt64(hour), unit: "h")
    fields.uint("minute", label: "Minute", UInt64(minute), unit: "min")
    fields.uint("second", label: "Second", UInt64(second), unit: "s")
    return true
}

private func monthName(_ value: UInt8) -> StaticString {
    switch value {
    case 1: return "January"
    case 2: return "February"
    case 3: return "March"
    case 4: return "April"
    case 5: return "May"
    case 6: return "June"
    case 7: return "July"
    case 8: return "August"
    case 9: return "September"
    case 10: return "October"
    case 11: return "November"
    case 12: return "December"
    default: return "Unknown"
    }
}

/// Reads the 1-byte Day of Week and emits its field. Returns false for invalid raw values.
private func readDayOfWeek(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let raw = payload.readUInt8() else { return false }
    let name: StaticString
    switch raw {
    case 0: name = "Unknown"
    case 1: name = "Monday"
    case 2: name = "Tuesday"
    case 3: name = "Wednesday"
    case 4: name = "Thursday"
    case 5: name = "Friday"
    case 6: name = "Saturday"
    case 7: name = "Sunday"
    default: return false
    }
    fields.string("day_of_week", label: "Day of Week", name)
    return true
}

/// Reads the 1-byte DST Offset and emits its field. Returns false for invalid raw values.
private func readDstOffset(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let raw = payload.readUInt8() else { return false }
    let name: StaticString
    switch raw {
    case 0: name = "Standard Time"
    case 2: name = "Half An Hour Daylight Time"
    case 4: name = "Daylight Time"
    case 8: name = "Double Daylight Time"
    case 255: name = "Unknown"
    default: return false
    }
    fields.string("dst_offset", label: "DST Offset", name)
    return true
}

/// Reads the 1-byte Time Zone and emits its field. Returns false for invalid raw values.
private func readTimeZone(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let raw = payload.readInt8() else { return false }
    // GATTTimeZone: unknown (-128) or -48...56, in 15 minute increments.
    guard raw == -128 || (raw >= -48 && raw <= 56) else { return false }
    if raw == -128 {
        fields.string("time_zone", label: "Time Zone", "Unknown")
    } else {
        fields.int("time_zone", label: "Time Zone", Int64(raw) * 15, unit: "min")
    }
    return true
}

/// Reads the 1-byte Time Source and emits its field. Returns false for invalid raw values.
private func readTimeSource(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let raw = payload.readUInt8() else { return false }
    let name: StaticString
    switch raw {
    case 0: name = "Unknown"
    case 1: name = "Network Time Protocol"
    case 2: name = "GPS"
    case 3: name = "Radio Time Signal"
    case 4: name = "Manual"
    case 5: name = "Atomic Clock"
    case 6: name = "Cellular Network"
    default: return false
    }
    fields.string("time_source", label: "Time Source", name)
    return true
}

/// Reads the 1-byte Time Accuracy and emits its field. Every raw value is valid.
private func readTimeAccuracy(_ payload: inout PayloadReader, into fields: inout Fields) -> Bool {
    guard let raw = payload.readUInt8() else { return false }
    switch raw {
    case 254:
        fields.string("time_accuracy", label: "Time Accuracy", "Out of Range")
    case 255:
        fields.string("time_accuracy", label: "Time Accuracy", "Unknown")
    default:
        // Steps of 1/8 second (125 ms).
        fields.double("time_accuracy", label: "Time Accuracy", Double(raw) / 8.0, unit: "s")
    }
    return true
}

// MARK: - Characteristics

/// Date Time (0x2A08).
private func dateTime(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 7 else { return nil }
    var fields = Fields(summary: "Date Time")
    guard readDateTime(&payload, into: &fields) else { return nil }
    return fields
}

/// Day of Week (0x2A09).
private func dayOfWeek(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }
    var fields = Fields(summary: "Day of Week")
    guard readDayOfWeek(&payload, into: &fields) else { return nil }
    return fields
}

/// Day Date Time (0x2A0A): Date Time followed by Day of Week.
private func dayDateTime(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 8 else { return nil }
    var fields = Fields(summary: "Day Date Time")
    guard readDateTime(&payload, into: &fields),
          readDayOfWeek(&payload, into: &fields)
    else { return nil }
    return fields
}

/// Exact Time 256 (0x2A0C): Day Date Time followed by 1/256ths of a second.
private func exactTime256(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 9 else { return nil }
    var fields = Fields(summary: "Exact Time 256")
    guard readDateTime(&payload, into: &fields),
          readDayOfWeek(&payload, into: &fields),
          let fractions = payload.readUInt8()
    else { return nil }
    fields.uint("fractions_256", label: "Fractions", UInt64(fractions), unit: "1/256 s")
    return fields
}

/// DST Offset (0x2A0D).
private func dstOffset(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }
    var fields = Fields(summary: "DST Offset")
    guard readDstOffset(&payload, into: &fields) else { return nil }
    return fields
}

/// Time Zone (0x2A0E).
private func timeZone(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }
    var fields = Fields(summary: "Time Zone")
    guard readTimeZone(&payload, into: &fields) else { return nil }
    return fields
}

/// Local Time Information (0x2A0F): Time Zone followed by DST Offset.
private func localTimeInformation(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2 else { return nil }
    var fields = Fields(summary: "Local Time Information")
    guard readTimeZone(&payload, into: &fields),
          readDstOffset(&payload, into: &fields)
    else { return nil }
    return fields
}

/// Time with DST (0x2A11): Date Time followed by DST Offset.
private func timeWithDst(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 8 else { return nil }
    var fields = Fields(summary: "Time with DST")
    guard readDateTime(&payload, into: &fields),
          readDstOffset(&payload, into: &fields)
    else { return nil }
    return fields
}

/// Time Accuracy (0x2A12).
private func timeAccuracy(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }
    var fields = Fields(summary: "Time Accuracy")
    guard readTimeAccuracy(&payload, into: &fields) else { return nil }
    return fields
}

/// Time Source (0x2A13).
private func timeSource(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1 else { return nil }
    var fields = Fields(summary: "Time Source")
    guard readTimeSource(&payload, into: &fields) else { return nil }
    return fields
}

/// Reference Time Information (0x2A14): time source, time accuracy, days and hours since update.
private func referenceTimeInformation(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 4 else { return nil }
    var fields = Fields(summary: "Reference Time Information")
    guard readTimeSource(&payload, into: &fields),
          readTimeAccuracy(&payload, into: &fields),
          let days = payload.readUInt8(),
          let hours = payload.readUInt8()
    else { return nil }
    // GATTReferenceTimeInformation.Hour: 255 ("more hours") or 0...23. Day accepts any value.
    guard hours == 255 || hours <= 23 else { return nil }

    if days == 255 {
        fields.string("days_since_update", label: "Days Since Update", "255 or More")
    } else {
        fields.uint("days_since_update", label: "Days Since Update", UInt64(days), unit: "d")
    }
    if hours == 255 {
        fields.string("hours_since_update", label: "Hours Since Update", "255 or More")
    } else {
        fields.uint("hours_since_update", label: "Hours Since Update", UInt64(hours), unit: "h")
    }
    return fields
}

/// Time Update Control Point (0x2A16).
private func timeUpdateControlPoint(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let raw = payload.readUInt8() else { return nil }
    let name: StaticString
    switch raw {
    case 1: name = "Get Reference Update"
    case 2: name = "Cancel Reference Update"
    default: return nil
    }
    var fields = Fields(summary: "Time Update Control Point")
    fields.string("command", label: "Command", name)
    return fields
}

/// Time Update State (0x2A17): current state and result of the last update.
private func timeUpdateState(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2,
          let stateRaw = payload.readUInt8(),
          let resultRaw = payload.readUInt8()
    else { return nil }

    let state: StaticString
    switch stateRaw {
    case 0: state = "Idle"
    case 1: state = "Update Pending"
    default: return nil
    }

    let result: StaticString
    switch resultRaw {
    case 0: result = "Successful"
    case 1: result = "Canceled"
    case 2: result = "No Connection To Reference"
    case 3: result = "Reference Responded With Error"
    case 4: result = "Timeout"
    case 5: result = "Update Not Attempted After Reset"
    default: return nil
    }

    var fields = Fields(summary: "Time Update State")
    fields.string("current_state", label: "Current State", state)
    fields.string("result", label: "Result", result)
    return fields
}

/// Current Time (0x2A2B): Exact Time 256 followed by the adjust reason bit mask.
private func currentTime(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 10 else { return nil }
    var fields = Fields(summary: "Current Time")
    guard readDateTime(&payload, into: &fields),
          readDayOfWeek(&payload, into: &fields),
          let fractions = payload.readUInt8(),
          let adjustReason = payload.readUInt8()
    else { return nil }
    fields.uint("fractions_256", label: "Fractions", UInt64(fractions), unit: "1/256 s")
    // Adjust reason is an unvalidated bit mask; report each defined flag.
    fields.bool("manual_time_update", label: "Manual Time Update", adjustReason & 0b0001 != 0)
    fields.bool("external_reference", label: "External Reference Time Update", adjustReason & 0b0010 != 0)
    fields.bool("time_zone_change", label: "Change of Time Zone", adjustReason & 0b0100 != 0)
    fields.bool("dst_change", label: "Change of DST", adjustReason & 0b1000 != 0)
    return fields
}

/// Date UTC (0x2AED): days elapsed since Jan 1 1970, as a 24-bit little-endian value.
private func dateUTC(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 3,
          let byte0 = payload.readUInt8(),
          let byte1 = payload.readUInt8(),
          let byte2 = payload.readUInt8()
    else { return nil }
    let raw = UInt32(byte0) | (UInt32(byte1) << 8) | (UInt32(byte2) << 16)
    // GATTDateUTC.Day: unknown (0) or 1...16_777_214.
    guard raw == 0 || raw <= 16_777_214 else { return nil }

    var fields = Fields(summary: "Date UTC")
    if raw == 0 {
        fields.string("date", label: "Date", "Unknown")
    } else {
        fields.uint("date", label: "Date", UInt64(raw), unit: "d")
    }
    return fields
}
