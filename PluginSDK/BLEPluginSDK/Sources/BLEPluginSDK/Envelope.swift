//
//  Envelope.swift
//  BLEPluginSDK
//
//  Decoding of the host's input envelope (ABI v1). See Documentation/PluginABI.md.
//

/// What kind of value is being parsed.
public enum ParseKind: UInt8 {
    case manufacturerData = 1
    case serviceData = 2
    case characteristic = 3
    case descriptor = 4
}

/// A 128-bit UUID as 16 RFC-4122 big-endian bytes.
public struct UUIDBytes {
    public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    public init(loading pointer: UnsafeRawPointer) {
        bytes = (
            pointer.load(fromByteOffset: 0, as: UInt8.self),
            pointer.load(fromByteOffset: 1, as: UInt8.self),
            pointer.load(fromByteOffset: 2, as: UInt8.self),
            pointer.load(fromByteOffset: 3, as: UInt8.self),
            pointer.load(fromByteOffset: 4, as: UInt8.self),
            pointer.load(fromByteOffset: 5, as: UInt8.self),
            pointer.load(fromByteOffset: 6, as: UInt8.self),
            pointer.load(fromByteOffset: 7, as: UInt8.self),
            pointer.load(fromByteOffset: 8, as: UInt8.self),
            pointer.load(fromByteOffset: 9, as: UInt8.self),
            pointer.load(fromByteOffset: 10, as: UInt8.self),
            pointer.load(fromByteOffset: 11, as: UInt8.self),
            pointer.load(fromByteOffset: 12, as: UInt8.self),
            pointer.load(fromByteOffset: 13, as: UInt8.self),
            pointer.load(fromByteOffset: 14, as: UInt8.self),
            pointer.load(fromByteOffset: 15, as: UInt8.self)
        )
    }

    /// The 16-bit assigned number, if this is a Bluetooth base UUID.
    public var assignedNumber16: UInt16 {
        (UInt16(bytes.2) << 8) | UInt16(bytes.3)
    }

    public func withBytes<R>(_ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        withUnsafeBytes(of: bytes) { raw in
            body(raw.bindMemory(to: UInt8.self))
        }
    }
}

/// The decoded input handed to a plugin's parse function.
public struct ParseInput {

    public let kind: ParseKind

    /// Manufacturer company identifier, valid when `kind == .manufacturerData`.
    public let companyIdentifier: UInt16?

    /// Attribute or service UUID, valid for the non-manufacturer kinds.
    public let uuid: UUIDBytes?

    /// A reader positioned at the start of the payload.
    public let payload: PayloadReader

    /// Decode the envelope the host wrote at `pointer`.
    public init?(pointer: UnsafeRawPointer, length: UInt32) {
        guard length >= 24 else { return nil }
        let version = pointer.load(fromByteOffset: 0, as: UInt8.self)
        guard version == 1 else { return nil }
        guard let kind = ParseKind(rawValue: pointer.load(fromByteOffset: 1, as: UInt8.self)) else {
            return nil
        }
        self.kind = kind

        let company = UInt16(pointer.load(fromByteOffset: 2, as: UInt8.self))
            | (UInt16(pointer.load(fromByteOffset: 3, as: UInt8.self)) << 8)
        self.companyIdentifier = (kind == .manufacturerData) ? company : nil
        self.uuid = (kind == .manufacturerData) ? nil : UUIDBytes(loading: pointer + 4)

        var payloadLength: UInt32 = 0
        for index in 0..<4 {
            payloadLength |= UInt32(pointer.load(fromByteOffset: 20 + index, as: UInt8.self)) << (8 * UInt32(index))
        }
        guard 24 + Int(payloadLength) <= Int(length) else { return nil }
        self.payload = PayloadReader(base: pointer + 24, count: Int(payloadLength))
    }
}
