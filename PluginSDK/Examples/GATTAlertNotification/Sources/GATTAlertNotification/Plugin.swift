//
//  Plugin.swift
//  GATTAlertNotification
//
//  Alert Notification service characteristics, ported from BluetoothGATT.
//
//  0x2A06 Alert Level                        0x2A45 Unread Alert Status
//  0x2A3F Alert Status                       0x2A46 New Alert
//  0x2A42 Alert Category ID Bit Mask         0x2A47 Supported New Alert Category
//  0x2A43 Alert Category ID                  0x2A48 Supported Unread Alert Category
//  0x2A44 Alert Notification Control Point
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A06: return alertLevel(input)
    case 0x2A3F: return alertStatus(input)
    case 0x2A42: return alertCategoryBitMask(input, summary: "Alert Category ID Bit Mask")
    case 0x2A43: return alertCategory(input)
    case 0x2A44: return alertNotificationControlPoint(input)
    case 0x2A45: return unreadAlertStatus(input)
    case 0x2A46: return newAlert(input)
    case 0x2A47: return alertCategoryBitMask(input, summary: "Supported New Alert Category")
    case 0x2A48: return alertCategoryBitMask(input, summary: "Supported Unread Alert Category")
    default: return nil
    }
}

// MARK: - Shared helpers

/// The `GATTAlertCategory` case name for a raw value, or `nil` for an undefined case.
private func alertCategoryName(_ rawValue: UInt8) -> StaticString? {
    switch rawValue {
    case 0: return "Simple Alert"
    case 1: return "Email"
    case 2: return "News"
    case 3: return "Call"
    case 4: return "Missed Call"
    case 5: return "SMS/MMS"
    case 6: return "Voice Mail"
    case 7: return "Schedule"
    case 8: return "High Prioritized Alert"
    case 9: return "Instant Message"
    default: return nil
    }
}

/// Port of `UInt64.init?(bitmaskArray:)`: little-endian, widening to the largest
/// power-of-two prefix that fits, and `nil` for an empty value.
private func bitmaskValue(_ payload: inout PayloadReader) -> UInt64? {
    let count = payload.remaining
    let width: Int
    if count == 8 {
        width = 8
    } else if count >= 4 {
        width = 4
    } else if count >= 2 {
        width = 2
    } else if count >= 1 {
        width = 1
    } else {
        return nil
    }
    var value: UInt64 = 0
    for index in 0..<width {
        guard let byte = payload.byte(at: index) else { return nil }
        value |= UInt64(byte) << (8 * UInt64(index))
    }
    return value
}

/// Validate a UTF-8 byte sequence, matching `String(utf8:)`'s rejection of malformed input.
private func isValidUTF8(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
    var index = 0
    while index < buffer.count {
        let byte = buffer[index]
        var continuations = 0
        var minimum: UInt32 = 0
        var scalar: UInt32 = 0
        if byte < 0x80 {
            index += 1
            continue
        } else if byte >= 0xC2 && byte <= 0xDF {
            continuations = 1
            minimum = 0x80
            scalar = UInt32(byte & 0x1F)
        } else if byte >= 0xE0 && byte <= 0xEF {
            continuations = 2
            minimum = 0x800
            scalar = UInt32(byte & 0x0F)
        } else if byte >= 0xF0 && byte <= 0xF4 {
            continuations = 3
            minimum = 0x1_0000
            scalar = UInt32(byte & 0x07)
        } else {
            return false
        }
        guard index + continuations < buffer.count else { return false }
        for offset in 1...continuations {
            let next = buffer[index + offset]
            guard next >= 0x80, next <= 0xBF else { return false }
            scalar = (scalar << 6) | UInt32(next & 0x3F)
        }
        // Reject overlong encodings, surrogates and out-of-range scalars.
        guard scalar >= minimum, scalar <= 0x10_FFFF else { return false }
        guard scalar < 0xD800 || scalar > 0xDFFF else { return false }
        index += continuations + 1
    }
    return true
}

// MARK: - Characteristics

/// Alert Level (0x2A06): one byte, `none` / `mild` / `high`.
private func alertLevel(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let rawValue = payload.readUInt8() else { return nil }
    let name: StaticString
    switch rawValue {
    case 0x00: name = "No Alert"
    case 0x01: name = "Mild Alert"
    case 0x02: name = "High Alert"
    default: return nil
    }
    var fields = Fields(summary: "Alert Level")
    fields.string("alert_level", label: "Alert Level", name)
    return fields
}

/// Alert Status (0x2A3F): one byte of state flags.
private func alertStatus(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let rawValue = payload.readUInt8() else { return nil }
    var fields = Fields(summary: "Alert Status")
    fields.bool("ringer", label: "Ringer State", rawValue & 0b001 != 0)
    fields.bool("vibrate", label: "Vibrate State", rawValue & 0b010 != 0)
    fields.bool("display_alert", label: "Display Alert State", rawValue & 0b100 != 0)
    return fields
}

/// Alert Category ID Bit Mask (0x2A42) and the two supported-category characteristics
/// (0x2A47, 0x2A48), which reuse the same bit mask format.
private func alertCategoryBitMask(_ input: ParseInput, summary: StaticString) -> Fields? {
    var payload = input.payload
    guard let bitmask = bitmaskValue(&payload) else { return nil }
    var fields = Fields(summary: summary)
    fields.bool("simple_alert", label: "Simple Alert", bitmask & 0b1 != 0)
    fields.bool("email", label: "Email", bitmask & 0b10 != 0)
    fields.bool("news", label: "News", bitmask & 0b100 != 0)
    fields.bool("call", label: "Call", bitmask & 0b1000 != 0)
    fields.bool("missed_call", label: "Missed Call", bitmask & 0b1_0000 != 0)
    fields.bool("sms", label: "SMS/MMS", bitmask & 0b10_0000 != 0)
    fields.bool("voice_mail", label: "Voice Mail", bitmask & 0b100_0000 != 0)
    fields.bool("schedule", label: "Schedule", bitmask & 0b1000_0000 != 0)
    fields.bool("high_prioritized", label: "High Prioritized Alert", bitmask & 0b1_0000_0000 != 0)
    fields.bool("instant_message", label: "Instant Message", bitmask & 0b10_0000_0000 != 0)
    return fields
}

/// Alert Category ID (0x2A43): one byte enumerating the alert category.
private func alertCategory(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1,
          let rawValue = payload.readUInt8(),
          let name = alertCategoryName(rawValue)
    else { return nil }
    var fields = Fields(summary: "Alert Category ID")
    fields.string("category", label: "Category", name)
    return fields
}

/// Alert Notification Control Point (0x2A44): command id followed by category id.
private func alertNotificationControlPoint(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2,
          let commandRawValue = payload.readUInt8(),
          let categoryRawValue = payload.readUInt8()
    else { return nil }
    let command: StaticString
    switch commandRawValue {
    case 0: command = "Enable New Incoming Alert Notification"
    case 1: command = "Enable Unread Category Status Notification"
    case 2: command = "Disable New Incoming Alert Notification"
    case 3: command = "Disable Unread Category Status Notification"
    case 4: command = "Notify New Incoming Alert Immediately"
    case 5: command = "Notify Unread Category Status Immediately"
    default: return nil
    }
    guard let category = alertCategoryName(categoryRawValue) else { return nil }
    var fields = Fields(summary: "Alert Notification Control Point")
    fields.string("command", label: "Command", command)
    fields.string("category", label: "Category", category)
    return fields
}

/// Unread Alert Status (0x2A45): category id followed by an unread count.
private func unreadAlertStatus(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 2,
          let categoryRawValue = payload.readUInt8(),
          let unreadCount = payload.readUInt8(),
          let category = alertCategoryName(categoryRawValue)
    else { return nil }
    var fields = Fields(summary: "Unread Alert Status")
    fields.string("category", label: "Category", category)
    fields.uint("unread_count", label: "Unread Count", UInt64(unreadCount))
    return fields
}

/// New Alert (0x2A46): category id, new alert count, then up to 18 bytes of UTF-8 text.
private func newAlert(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining >= 2,
          let categoryRawValue = payload.readUInt8(),
          let newAlertsCount = payload.readUInt8(),
          let category = alertCategoryName(categoryRawValue)
    else { return nil }
    // `GATTNewAlert.Information` accepts 0...18 UTF-8 bytes and rejects malformed text.
    guard payload.remaining <= 18 else { return nil }
    guard payload.remainingBytes({ isValidUTF8($0) }) else { return nil }

    var fields = Fields(summary: "New Alert")
    fields.string("category", label: "Category", category)
    fields.uint("new_alerts_count", label: "New Alerts Count", UInt64(newAlertsCount))
    payload.remainingBytes { buffer in
        fields.text("information", label: "Information", utf8: buffer)
    }
    return fields
}
