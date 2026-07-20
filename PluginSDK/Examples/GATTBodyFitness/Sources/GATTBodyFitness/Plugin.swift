//
//  Plugin.swift
//  GATTBodyFitness
//
//  Body composition and fitness machine characteristics, ported from BluetoothGATT.
//
//  0x2A38 Body Sensor Location
//  0x2A9C Body Composition Measurement
//  0x2ACE Cross Trainer Data
//

import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard let uuid = input.uuid else { return nil }
    switch uuid.assignedNumber16 {
    case 0x2A38: return bodySensorLocation(input)
    case 0x2A9C: return bodyCompositionMeasurement(input)
    case 0x2ACE: return crossTrainerData(input)
    default: return nil
    }
}

// MARK: - Byte access helpers

/// Little-endian 16-bit load at an absolute offset, mirroring `UInt16(bytes: (data[i], data[i+1]))`.
private func uint16LE(_ payload: PayloadReader, _ index: Int) -> UInt16? {
    guard let low = payload.byte(at: index), let high = payload.byte(at: index + 1) else { return nil }
    return (UInt16(high) << 8) | UInt16(low)
}

/// Little-endian 24-bit load at an absolute offset.
private func uint24LE(_ payload: PayloadReader, _ index: Int) -> UInt32? {
    guard let byte0 = payload.byte(at: index),
          let byte1 = payload.byte(at: index + 1),
          let byte2 = payload.byte(at: index + 2)
    else { return nil }
    return UInt32(byte0) | (UInt32(byte1) << 8) | (UInt32(byte2) << 16)
}

private func int16LE(_ payload: PayloadReader, _ index: Int) -> Int16? {
    uint16LE(payload, index).map { Int16(bitPattern: $0) }
}

// MARK: - 0x2A38 Body Sensor Location

/// Body Sensor Location: a single byte enumeration. BluetoothGATT requires exactly one byte and
/// rejects raw values outside 0x00...0x06.
private func bodySensorLocation(_ input: ParseInput) -> Fields? {
    var payload = input.payload
    guard payload.remaining == 1, let raw = payload.readUInt8() else { return nil }

    let name: StaticString
    switch raw {
    case 0x00: name = "Other"
    case 0x01: name = "Chest"
    case 0x02: name = "Wrist"
    case 0x03: name = "Finger"
    case 0x04: name = "Hand"
    case 0x05: name = "Ear Lobe"
    case 0x06: name = "Foot"
    default: return nil
    }

    var fields = Fields(summary: "Body Sensor Location")
    fields.string("body_sensor_location", label: "Body Sensor Location", name)
    return fields
}

// MARK: - 0x2A9C Body Composition Measurement

private enum BodyCompositionFlag {
    static let measurementUnitImperial: UInt16 = 0b1
    static let timestamp: UInt16 = 0b10
    static let userID: UInt16 = 0b100
    static let basalMetabolism: UInt16 = 0b1000
    static let musclePercentage: UInt16 = 0b1_0000
    static let muscleMass: UInt16 = 0b10_0000
    static let fatFreeMass: UInt16 = 0b100_0000
    static let softLeanMass: UInt16 = 0b1000_0000
    static let bodyWaterMass: UInt16 = 0b1_0000_0000
    static let impedance: UInt16 = 0b10_0000_0000
    static let weight: UInt16 = 0b100_0000_0000
    static let height: UInt16 = 0b1000_0000_0000
    static let multiplePacket: UInt16 = 0b1_0000_0000_0000
}

/// Body Composition Measurement (0x2A9C).
///
/// Flags (16-bit LE) then body fat percentage (16-bit LE), followed by optional fields in a fixed
/// order gated by the flag bits. Bit 0 selects Imperial units (pound / inch) instead of SI
/// (kilogram / metre). The bounds checks reproduce BluetoothGATT exactly, including its use of a
/// strict `index + size < data.count` comparison against a cursor that trails the last byte read.
private func bodyCompositionMeasurement(_ input: ParseInput) -> Fields? {
    let payload = input.payload
    let count = payload.count
    guard count >= 4 else { return nil }
    guard let flags = uint16LE(payload, 0), let bodyFat = uint16LE(payload, 2) else { return nil }

    let imperial = (flags & BodyCompositionFlag.measurementUnitImperial) != 0
    let massUnit: StaticString = imperial ? "lb" : "kg"
    let lengthUnit: StaticString = imperial ? "in" : "m"

    var fields = Fields(summary: "Body Composition Measurement")
    fields.string(
        "measurement_units", label: "Measurement Units",
        imperial ? "Imperial" : "SI"
    )
    fields.uint("body_fat_percentage", label: "Body Fat Percentage", UInt64(bodyFat), unit: "%")

    var index = 3

    if (flags & BodyCompositionFlag.timestamp) != 0 {
        // GATTDateTime.length == 7
        guard index + 7 < count else { return nil }
        guard let year = uint16LE(payload, index + 1),
              let month = payload.byte(at: index + 3),
              let day = payload.byte(at: index + 4),
              let hour = payload.byte(at: index + 5),
              let minute = payload.byte(at: index + 6),
              let second = payload.byte(at: index + 7)
        else { return nil }
        // GATTDateTime rejects out-of-range components.
        guard year == 0 || (year >= 1582 && year <= 9999),
              month <= 12,
              day == 0 || (day >= 1 && day <= 31),
              hour <= 23,
              minute <= 59,
              second <= 59
        else { return nil }

        fields.uint("timestamp_year", label: "Year", UInt64(year))
        fields.uint("timestamp_month", label: "Month", UInt64(month))
        fields.uint("timestamp_day", label: "Day", UInt64(day))
        fields.uint("timestamp_hour", label: "Hour", UInt64(hour))
        fields.uint("timestamp_minute", label: "Minute", UInt64(minute))
        fields.uint("timestamp_second", label: "Second", UInt64(second))
        index += 7
    }

    if (flags & BodyCompositionFlag.userID) != 0 {
        guard index + 1 < count, let user = payload.byte(at: index + 1) else { return nil }
        fields.uint("user_identifier", label: "User Identifier", UInt64(user))
        index += 1
    }

    if (flags & BodyCompositionFlag.basalMetabolism) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("basal_metabolism", label: "Basal Metabolism", UInt64(value), unit: "kJ")
        index += 2
    }

    if (flags & BodyCompositionFlag.musclePercentage) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("muscle_percentage", label: "Muscle Percentage", UInt64(value), unit: "%")
        index += 2
    }

    if (flags & BodyCompositionFlag.muscleMass) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("muscle_mass", label: "Muscle Mass", UInt64(value), unit: massUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.fatFreeMass) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("fat_free_mass", label: "Fat Free Mass", UInt64(value), unit: massUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.softLeanMass) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("soft_lean_mass", label: "Soft Lean Mass", UInt64(value), unit: massUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.bodyWaterMass) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("body_water_mass", label: "Body Water Mass", UInt64(value), unit: massUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.impedance) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("impedance", label: "Impedance", UInt64(value))
        index += 2
    }

    if (flags & BodyCompositionFlag.weight) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("weight", label: "Weight", UInt64(value), unit: massUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.height) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("height", label: "Height", UInt64(value), unit: lengthUnit)
        index += 2
    }

    if (flags & BodyCompositionFlag.multiplePacket) != 0 {
        fields.bool("multiple_packet_measurement", label: "Multiple Packet Measurement", true)
    }

    return fields
}

// MARK: - 0x2ACE Cross Trainer Data

private enum CrossTrainerFlag {
    static let moreData: UInt32 = 0b1
    static let averageSpeed: UInt32 = 0b10
    static let totalDistance: UInt32 = 0b100
    static let stepCount: UInt32 = 0b1000
    static let strideCount: UInt32 = 0b1_0000
    static let elevationGain: UInt32 = 0b10_0000
    static let inclinationAndRampAngleSetting: UInt32 = 0b100_0000
    static let resistanceLevel: UInt32 = 0b1000_0000
    static let instantaneousPower: UInt32 = 0b1_0000_0000
    static let averagePower: UInt32 = 0b10_0000_0000
    static let expendedEnergy: UInt32 = 0b100_0000_0000
    static let heartRate: UInt32 = 0b1000_0000_0000
    static let metabolicEquivalent: UInt32 = 0b1_0000_0000_0000
    static let elapsedTime: UInt32 = 0b10_0000_0000_0000
    static let remainingTime: UInt32 = 0b100_0000_0000_0000
    static let movementDirection: UInt32 = 0b1000_0000_0000_0000
}

/// Cross Trainer Data (0x2ACE).
///
/// A 24-bit little-endian flags field followed by optional fields in a fixed order. As in
/// BluetoothGATT the cursor starts at 2 and every field reads from `index + 1`, with a strict
/// `index + size < data.count` bounds check.
private func crossTrainerData(_ input: ParseInput) -> Fields? {
    let payload = input.payload
    let count = payload.count
    guard count >= 3 else { return nil }
    guard let flags = uint24LE(payload, 0) else { return nil }

    var fields = Fields(summary: "Cross Trainer Data")
    var index = 2

    if (flags & CrossTrainerFlag.moreData) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("instantaneous_speed", label: "Instantaneous Speed", UInt64(value), unit: "km/h")
        index += 2
    }

    if (flags & CrossTrainerFlag.averageSpeed) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("average_speed", label: "Average Speed", UInt64(value), unit: "km/h")
        index += 2
    }

    if (flags & CrossTrainerFlag.totalDistance) != 0 {
        guard index + 3 < count, let value = uint24LE(payload, index + 1) else { return nil }
        fields.uint("total_distance", label: "Total Distance", UInt64(value), unit: "m")
        index += 3
    }

    if (flags & CrossTrainerFlag.stepCount) != 0 {
        guard index + 4 < count,
              let steps = uint16LE(payload, index + 1),
              let averageRate = uint16LE(payload, index + 3)
        else { return nil }
        fields.uint("step_per_minute", label: "Step Per Minute", UInt64(steps), unit: "steps/min")
        fields.uint("average_step_rate", label: "Average Step Rate", UInt64(averageRate), unit: "steps/min")
        index += 4
    }

    if (flags & CrossTrainerFlag.strideCount) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("stride_count", label: "Stride Count", UInt64(value))
        index += 2
    }

    if (flags & CrossTrainerFlag.elevationGain) != 0 {
        guard index + 4 < count,
              let positive = uint16LE(payload, index + 1),
              let negative = uint16LE(payload, index + 3)
        else { return nil }
        fields.uint("positive_elevation_gain", label: "Positive Elevation Gain", UInt64(positive), unit: "m")
        fields.uint("negative_elevation_gain", label: "Negative Elevation Gain", UInt64(negative), unit: "m")
        index += 4
    }

    if (flags & CrossTrainerFlag.inclinationAndRampAngleSetting) != 0 {
        guard index + 4 < count,
              let inclination = int16LE(payload, index + 1),
              let rampAngle = int16LE(payload, index + 3)
        else { return nil }
        fields.int("inclination", label: "Inclination", Int64(inclination), unit: "%")
        fields.int("ramp_angle_setting", label: "Ramp Angle Setting", Int64(rampAngle), unit: "degrees")
        index += 4
    }

    if (flags & CrossTrainerFlag.resistanceLevel) != 0 {
        guard index + 2 < count, let value = int16LE(payload, index + 1) else { return nil }
        fields.int("resistance_level", label: "Resistance Level", Int64(value))
        index += 2
    }

    if (flags & CrossTrainerFlag.instantaneousPower) != 0 {
        guard index + 2 < count, let value = int16LE(payload, index + 1) else { return nil }
        fields.int("instantaneous_power", label: "Instantaneous Power", Int64(value), unit: "W")
        index += 2
    }

    if (flags & CrossTrainerFlag.averagePower) != 0 {
        guard index + 2 < count, let value = int16LE(payload, index + 1) else { return nil }
        fields.int("average_power", label: "Average Power", Int64(value), unit: "W")
        index += 2
    }

    if (flags & CrossTrainerFlag.expendedEnergy) != 0 {
        guard index + 5 < count,
              let total = uint16LE(payload, index + 1),
              let perHour = uint16LE(payload, index + 3),
              let perMinute = payload.byte(at: index + 5)
        else { return nil }
        fields.uint("total_energy", label: "Total Energy", UInt64(total), unit: "kcal")
        fields.uint("energy_per_hour", label: "Energy Per Hour", UInt64(perHour), unit: "kcal")
        fields.uint("energy_per_minute", label: "Energy Per Minute", UInt64(perMinute), unit: "kcal")
        index += 5
    }

    if (flags & CrossTrainerFlag.heartRate) != 0 {
        guard index + 1 < count, let value = payload.byte(at: index + 1) else { return nil }
        fields.uint("heart_rate", label: "Heart Rate", UInt64(value), unit: "bpm")
        index += 1
    }

    if (flags & CrossTrainerFlag.metabolicEquivalent) != 0 {
        guard index + 1 < count, let value = payload.byte(at: index + 1) else { return nil }
        fields.uint("metabolic_equivalent", label: "Metabolic Equivalent", UInt64(value))
        index += 1
    }

    if (flags & CrossTrainerFlag.elapsedTime) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("elapsed_time", label: "Elapsed Time", UInt64(value), unit: "s")
        index += 2
    }

    if (flags & CrossTrainerFlag.remainingTime) != 0 {
        guard index + 2 < count, let value = uint16LE(payload, index + 1) else { return nil }
        fields.uint("remaining_time", label: "Remaining Time", UInt64(value), unit: "s")
        index += 2
    }

    if (flags & CrossTrainerFlag.movementDirection) != 0 {
        fields.string("movement_direction", label: "Movement Direction", "Backward")
    } else {
        fields.string("movement_direction", label: "Movement Direction", "Forward")
    }

    return fields
}
