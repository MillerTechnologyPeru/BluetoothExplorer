//
//  Fields.swift
//  BLEPluginSDK
//
//  Builds the CBOR result envelope described in Documentation/PluginABI.md:
//    { 0: summary?, 1: [ {0: key, 1: label, 2: value, 3: unit?} ] }
//  Fields are encoded as they are added; `encode()` wraps them with the map and array headers.
//

public struct Fields {

    private var encodedFields: [UInt8] = []
    private var count: Int = 0
    private var summary: StaticString?

    public init(summary: StaticString? = nil) {
        self.summary = summary
    }

    public var isEmpty: Bool { count == 0 }

    // MARK: Adding fields

    public mutating func uint(
        _ key: StaticString, label: StaticString, _ value: UInt64, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        CBOR.appendUnsigned(major: 0, value: value, to: &encodedFields)
        endField(unit: unit)
    }

    public mutating func int(
        _ key: StaticString, label: StaticString, _ value: Int64, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        if value < 0 {
            CBOR.appendUnsigned(major: 1, value: UInt64(bitPattern: -1 - value), to: &encodedFields)
        } else {
            CBOR.appendUnsigned(major: 0, value: UInt64(value), to: &encodedFields)
        }
        endField(unit: unit)
    }

    public mutating func bool(
        _ key: StaticString, label: StaticString, _ value: Bool, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        encodedFields.append(value ? 0xF5 : 0xF4)
        endField(unit: unit)
    }

    public mutating func double(
        _ key: StaticString, label: StaticString, _ value: Double, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        encodedFields.append(0xFB)
        let bits = value.bitPattern
        for shift in stride(from: 56, through: 0, by: -8) {
            encodedFields.append(UInt8((bits >> UInt64(shift)) & 0xFF))
        }
        endField(unit: unit)
    }

    /// A string value known at compile time.
    public mutating func string(
        _ key: StaticString, label: StaticString, _ value: StaticString, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        CBOR.appendText(value, to: &encodedFields)
        endField(unit: unit)
    }

    /// A string value read from the payload, as raw UTF-8 bytes.
    public mutating func text(
        _ key: StaticString, label: StaticString, utf8: UnsafeBufferPointer<UInt8>, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        CBOR.appendUnsigned(major: 3, value: UInt64(utf8.count), to: &encodedFields)
        for byte in utf8 { encodedFields.append(byte) }
        endField(unit: unit)
    }

    /// Raw bytes; the host renders these as hexadecimal.
    public mutating func bytes(
        _ key: StaticString, label: StaticString, _ buffer: UnsafeBufferPointer<UInt8>, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        CBOR.appendUnsigned(major: 2, value: UInt64(buffer.count), to: &encodedFields)
        for byte in buffer { encodedFields.append(byte) }
        endField(unit: unit)
    }

    /// A 128-bit UUID, emitted under CBOR tag 37.
    public mutating func uuid(
        _ key: StaticString, label: StaticString, _ value: UUIDBytes, unit: StaticString? = nil
    ) {
        beginField(key: key, label: label, hasUnit: unit != nil)
        CBOR.appendUnsigned(major: 6, value: 37, to: &encodedFields)
        CBOR.appendUnsigned(major: 2, value: 16, to: &encodedFields)
        value.withBytes { buffer in
            for byte in buffer { encodedFields.append(byte) }
        }
        endField(unit: unit)
    }

    // MARK: Encoding

    /// The complete CBOR result envelope.
    public func encode() -> [UInt8] {
        var output: [UInt8] = []
        if let summary {
            CBOR.appendUnsigned(major: 5, value: 2, to: &output) // map(2)
            CBOR.appendUnsigned(major: 0, value: 0, to: &output) // key 0
            CBOR.appendText(summary, to: &output)
        } else {
            CBOR.appendUnsigned(major: 5, value: 1, to: &output) // map(1)
        }
        CBOR.appendUnsigned(major: 0, value: 1, to: &output)     // key 1
        CBOR.appendUnsigned(major: 4, value: UInt64(count), to: &output) // array(count)
        output.append(contentsOf: encodedFields)
        return output
    }

    // MARK: Internals

    private mutating func beginField(key: StaticString, label: StaticString, hasUnit: Bool) {
        count += 1
        CBOR.appendUnsigned(major: 5, value: hasUnit ? 4 : 3, to: &encodedFields) // map(3|4)
        CBOR.appendUnsigned(major: 0, value: 0, to: &encodedFields)               // key 0
        CBOR.appendText(key, to: &encodedFields)
        CBOR.appendUnsigned(major: 0, value: 1, to: &encodedFields)               // key 1
        CBOR.appendText(label, to: &encodedFields)
        CBOR.appendUnsigned(major: 0, value: 2, to: &encodedFields)               // key 2 (value follows)
    }

    private mutating func endField(unit: StaticString?) {
        guard let unit else { return }
        CBOR.appendUnsigned(major: 0, value: 3, to: &encodedFields)               // key 3
        CBOR.appendText(unit, to: &encodedFields)
    }
}

/// Minimal CBOR writing primitives.
enum CBOR {

    /// Append a major-type header carrying `value` as its argument.
    static func appendUnsigned(major: UInt8, value: UInt64, to output: inout [UInt8]) {
        let high = major << 5
        switch value {
        case 0...23:
            output.append(high | UInt8(value))
        case 24...0xFF:
            output.append(high | 24)
            output.append(UInt8(value))
        case 0x100...0xFFFF:
            output.append(high | 25)
            output.append(UInt8((value >> 8) & 0xFF))
            output.append(UInt8(value & 0xFF))
        case 0x1_0000...0xFFFF_FFFF:
            output.append(high | 26)
            for shift in stride(from: 24, through: 0, by: -8) {
                output.append(UInt8((value >> UInt64(shift)) & 0xFF))
            }
        default:
            output.append(high | 27)
            for shift in stride(from: 56, through: 0, by: -8) {
                output.append(UInt8((value >> UInt64(shift)) & 0xFF))
            }
        }
    }

    static func appendText(_ string: StaticString, to output: inout [UInt8]) {
        guard string.hasPointerRepresentation else {
            appendUnsigned(major: 3, value: 0, to: &output)
            return
        }
        let count = string.utf8CodeUnitCount
        appendUnsigned(major: 3, value: UInt64(count), to: &output)
        let start = string.utf8Start
        for index in 0..<count {
            output.append(start[index])
        }
    }
}
