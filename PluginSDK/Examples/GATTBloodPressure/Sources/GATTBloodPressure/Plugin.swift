//
//  Plugin.swift
//  GATTBloodPressure
//
//  Blood Pressure service characteristics, ported from BluetoothGATT.
//
//  0x2A35 Blood Pressure Measurement
//  0x2A49 Blood Pressure Feature
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A35: return bloodPressureMeasurement(input)
    case 0x2A49: return bloodPressureFeature(input)
    default: return nil
    }
}

// MARK: - IEEE-11073 16-bit SFLOAT

/// The special values an IEEE-11073 SFLOAT mantissa can carry.
private enum SFloatSpecial {
    /// A finite value.
    case finite(Double)
    /// Not a Number: the subfield is unavailable.
    case notANumber
    /// Not at this Resolution.
    case notAtThisResolution
    case positiveInfinity
    case negativeInfinity
    case reserved
}

/// Decode an IEEE-11073 16-bit SFLOAT: a 4-bit signed exponent in the high nibble and a
/// 12-bit signed mantissa in the low 12 bits, both two's complement.
///
/// Mantissa values 0x07FE...0x0802 are reserved for the special values defined in
/// ISO/IEEE 11073-20601a section 4, which the Blood Pressure specification uses to signal
/// unavailable subfields.
private func decodeSFloat(_ bitPattern: UInt16) -> SFloatSpecial {
    let rawMantissa = bitPattern & 0x0FFF
    switch rawMantissa {
    case 0x07FF: return .notANumber
    case 0x0800: return .notAtThisResolution
    case 0x07FE: return .positiveInfinity
    case 0x0802: return .negativeInfinity
    case 0x0801: return .reserved
    default: break
    }

    // Sign extend the 12-bit mantissa and the 4-bit exponent.
    var mantissa = Int32(rawMantissa)
    if mantissa >= 0x0800 { mantissa -= 0x1000 }
    var exponent = Int32((bitPattern >> 12) & 0x000F)
    if exponent >= 0x0008 { exponent -= 0x0010 }

    var value = Double(mantissa)
    if exponent > 0 {
        for _ in 0..<exponent { value *= 10 }
    } else if exponent < 0 {
        for _ in 0..<(-exponent) { value /= 10 }
    }
    return .finite(value)
}

/// Emit an SFLOAT subfield, rendering the IEEE-11073 special values as text.
private func appendSFloat(
    _ fields: inout Fields, _ key: StaticString, label: StaticString,
    _ bitPattern: UInt16, unit: StaticString
) {
    switch decodeSFloat(bitPattern) {
    case .finite(let value):
        fields.double(key, label: label, value, unit: unit)
    case .notANumber:
        fields.string(key, label: label, "Unavailable (NaN)")
    case .notAtThisResolution:
        fields.string(key, label: label, "Not at this Resolution")
    case .positiveInfinity:
        fields.string(key, label: label, "+Infinity")
    case .negativeInfinity:
        fields.string(key, label: label, "-Infinity")
    case .reserved:
        fields.string(key, label: label, "Reserved")
    }
}

// MARK: - Characteristics

/// Blood Pressure Measurement (0x2A35): a flags byte, a three-subfield SFLOAT compound value
/// and, per the flags, a timestamp, pulse rate, user id and measurement status.
private func bloodPressureMeasurement(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    // Flags plus the seven-byte compound value are mandatory.
    guard payload.remaining >= 7,
          let flags = payload.readUInt8(),
          let systolic = payload.readUInt16LittleEndian(),
          let diastolic = payload.readUInt16LittleEndian(),
          let meanArterialPressure = payload.readUInt16LittleEndian()
    else { return nil }

    let isKilopascals = (flags & 0b1) != 0
    let hasTimestamp = (flags & 0b10) != 0
    let hasPulseRate = (flags & 0b100) != 0
    let hasUserIdentifier = (flags & 0b1000) != 0
    let hasMeasurementStatus = (flags & 0b10000) != 0

    var fields = Fields(summary: "Blood Pressure Measurement")
    fields.string(
        "unit", label: "Unit",
        isKilopascals ? "Kilo Pascal" : "Millimetre of Mercury"
    )
    if isKilopascals {
        appendSFloat(&fields, "systolic", label: "Systolic", systolic, unit: "kPa")
        appendSFloat(&fields, "diastolic", label: "Diastolic", diastolic, unit: "kPa")
        appendSFloat(
            &fields, "mean_arterial_pressure", label: "Mean Arterial Pressure",
            meanArterialPressure, unit: "kPa"
        )
    } else {
        appendSFloat(&fields, "systolic", label: "Systolic", systolic, unit: "mmHg")
        appendSFloat(&fields, "diastolic", label: "Diastolic", diastolic, unit: "mmHg")
        appendSFloat(
            &fields, "mean_arterial_pressure", label: "Mean Arterial Pressure",
            meanArterialPressure, unit: "mmHg"
        )
    }

    if hasTimestamp {
        // GATTDateTime is seven bytes and rejects out-of-range components.
        guard payload.remaining >= 7,
              let year = payload.readUInt16LittleEndian(),
              let month = payload.readUInt8(),
              let day = payload.readUInt8(),
              let hour = payload.readUInt8(),
              let minute = payload.readUInt8(),
              let second = payload.readUInt8()
        else { return nil }
        guard year == 0 || (year >= 1582 && year <= 9999) else { return nil }
        guard month <= 12 else { return nil }
        guard day == 0 || (day >= 1 && day <= 31) else { return nil }
        guard hour <= 23, minute <= 59, second <= 59 else { return nil }

        fields.uint("year", label: "Year", UInt64(year))
        fields.uint("month", label: "Month", UInt64(month))
        fields.uint("day", label: "Day", UInt64(day))
        fields.uint("hour", label: "Hour", UInt64(hour))
        fields.uint("minute", label: "Minute", UInt64(minute))
        fields.uint("second", label: "Second", UInt64(second))
    }

    if hasPulseRate {
        guard let pulseRate = payload.readUInt16LittleEndian() else { return nil }
        appendSFloat(&fields, "pulse_rate", label: "Pulse Rate", pulseRate, unit: "bpm")
    }

    if hasUserIdentifier {
        guard let userIdentifier = payload.readUInt8() else { return nil }
        fields.uint("user_identifier", label: "User ID", UInt64(userIdentifier))
    }

    if hasMeasurementStatus {
        guard let status = payload.readUInt16LittleEndian() else { return nil }
        fields.bool("body_movement_detected", label: "Body Movement Detected", (status & 0b1) != 0)
        fields.bool("cuff_fit_detected", label: "Cuff Fit Detected", (status & 0b10) != 0)
        fields.bool("irregular_pulse_detected", label: "Irregular Pulse Detected", (status & 0b100) != 0)
        fields.bool("pulse_rate_range_detected", label: "Pulse Rate Range Detected", (status & 0b1000) != 0)
        fields.bool("measurement_position_detected", label: "Measurement Position Detected", (status & 0b10000) != 0)
    }

    return fields
}

/// Blood Pressure Feature (0x2A49): a 16-bit bit mask of supported sensor features.
private func bloodPressureFeature(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining >= 2,
          let features = payload.readUInt16LittleEndian()
    else { return nil }

    var fields = Fields(summary: "Blood Pressure Feature")
    fields.bool("body_movement_detection", label: "Body Movement Detection", (features & 0b1) != 0)
    fields.bool("cuff_fit_detection", label: "Cuff Fit Detection", (features & 0b10) != 0)
    fields.bool("irregular_pulse_detection", label: "Irregular Pulse Detection", (features & 0b100) != 0)
    fields.bool("pulse_rate_range_detection", label: "Pulse Rate Range Detection", (features & 0b1000) != 0)
    fields.bool("measurement_position_detection", label: "Measurement Position Detection", (features & 0b10000) != 0)
    fields.bool("multiple_bond", label: "Multiple Bond Support", (features & 0b100000) != 0)
    return fields
}
