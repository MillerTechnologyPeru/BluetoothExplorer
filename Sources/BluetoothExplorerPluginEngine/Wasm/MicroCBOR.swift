//
//  MicroCBOR.swift
//  BluetoothExplorerPluginEngine
//
//  A deliberately small, strict CBOR reader for decoding plugin output. Plugin output is
//  untrusted input to the host, so the reader accepts only the subset the ABI uses and
//  enforces depth / count / length caps. Definite-length items only.
//

import Foundation

/// A minimal CBOR value, limited to the types the plugin ABI carries.
enum CBORValue: Equatable {
    case uint(UInt64)
    case negative(Int64)
    case bytes([UInt8])
    /// A 16-byte value carried under CBOR tag 37 (UUID).
    case uuid([UInt8])
    case text(String)
    case array([CBORValue])
    case map([(CBORValue, CBORValue)])
    case bool(Bool)
    case double(Double)
    case null

    static func == (lhs: CBORValue, rhs: CBORValue) -> Bool {
        switch (lhs, rhs) {
        case let (.uint(a), .uint(b)): return a == b
        case let (.negative(a), .negative(b)): return a == b
        case let (.bytes(a), .bytes(b)): return a == b
        case let (.uuid(a), .uuid(b)): return a == b
        case let (.text(a), .text(b)): return a == b
        case let (.array(a), .array(b)): return a == b
        case let (.bool(a), .bool(b)): return a == b
        case let (.double(a), .double(b)): return a == b
        case (.null, .null): return true
        case let (.map(a), .map(b)):
            guard a.count == b.count else { return false }
            for i in a.indices where a[i].0 != b[i].0 || a[i].1 != b[i].1 { return false }
            return true
        default: return false
        }
    }
}

struct MicroCBORError: Error, Equatable {
    let message: String
}

/// A strict subset CBOR decoder. Not general-purpose.
struct MicroCBOR {

    /// CBOR tag marking a 16-byte UUID payload (RFC 4122 / IANA tag 37).
    static let uuidTag: UInt64 = 37

    private let bytes: [UInt8]
    private var offset = 0
    private let maxDepth: Int
    private let maxItems: Int
    private let maxStringBytes: Int

    init(bytes: [UInt8], maxDepth: Int = 8, maxItems: Int = 64, maxStringBytes: Int = 1024) {
        self.bytes = bytes
        self.maxDepth = maxDepth
        self.maxItems = maxItems
        self.maxStringBytes = maxStringBytes
    }

    static func decode(_ bytes: [UInt8]) throws -> CBORValue {
        var decoder = MicroCBOR(bytes: bytes)
        let value = try decoder.parseValue(depth: 0)
        guard decoder.offset == bytes.count else {
            throw MicroCBORError(message: "trailing bytes after top-level item")
        }
        return value
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < bytes.count else { throw MicroCBORError(message: "unexpected end of input") }
        defer { offset += 1 }
        return bytes[offset]
    }

    private mutating func readBigEndian(_ count: Int) throws -> UInt64 {
        var value: UInt64 = 0
        for _ in 0..<count {
            value = (value << 8) | UInt64(try readByte())
        }
        return value
    }

    /// Read the argument encoded by the low 5 bits of an initial byte.
    private mutating func readArgument(_ additional: UInt8) throws -> UInt64 {
        switch additional {
        case 0...23: return UInt64(additional)
        case 24: return UInt64(try readByte())
        case 25: return try readBigEndian(2)
        case 26: return try readBigEndian(4)
        case 27: return try readBigEndian(8)
        default: throw MicroCBORError(message: "unsupported additional info \(additional)")
        }
    }

    private mutating func parseValue(depth: Int) throws -> CBORValue {
        guard depth <= maxDepth else { throw MicroCBORError(message: "max depth exceeded") }
        let initial = try readByte()
        let majorType = initial >> 5
        let additional = initial & 0x1F

        switch majorType {
        case 0: // unsigned integer
            return .uint(try readArgument(additional))
        case 1: // negative integer
            let value = try readArgument(additional)
            return .negative(-1 - Int64(bitPattern: value))
        case 2: // byte string
            let length = try readLength(additional)
            return .bytes(try readRaw(length))
        case 3: // text string
            let length = try readLength(additional)
            let raw = try readRaw(length)
            guard let string = String(bytes: raw, encoding: .utf8) else {
                throw MicroCBORError(message: "invalid UTF-8 text string")
            }
            return .text(string)
        case 4: // array
            let count = try readCount(additional)
            var items = [CBORValue]()
            items.reserveCapacity(count)
            for _ in 0..<count {
                items.append(try parseValue(depth: depth + 1))
            }
            return .array(items)
        case 5: // map
            let count = try readCount(additional)
            var pairs = [(CBORValue, CBORValue)]()
            pairs.reserveCapacity(count)
            for _ in 0..<count {
                let key = try parseValue(depth: depth + 1)
                let value = try parseValue(depth: depth + 1)
                pairs.append((key, value))
            }
            return .map(pairs)
        case 6: // tag
            let tag = try readArgument(additional)
            let inner = try parseValue(depth: depth + 1)
            if tag == Self.uuidTag {
                // Enforce a 16-byte payload for UUID tags but keep it as bytes;
                // the mapping layer converts.
                guard case let .bytes(raw) = inner, raw.count == 16 else {
                    throw MicroCBORError(message: "tag 37 requires 16-byte string")
                }
                return .uuid(raw)
            }
            return inner
        case 7: // simple / float
            switch additional {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22, 23: return .null
            case 27:
                let bits = try readBigEndian(8)
                return .double(Double(bitPattern: bits))
            default:
                throw MicroCBORError(message: "unsupported simple value \(additional)")
            }
        default:
            throw MicroCBORError(message: "unsupported major type \(majorType)")
        }
    }

    private mutating func readLength(_ additional: UInt8) throws -> Int {
        let value = try readArgument(additional)
        guard value <= UInt64(maxStringBytes) else {
            throw MicroCBORError(message: "string length exceeds cap")
        }
        return Int(value)
    }

    private mutating func readCount(_ additional: UInt8) throws -> Int {
        let value = try readArgument(additional)
        guard value <= UInt64(maxItems) else {
            throw MicroCBORError(message: "collection count exceeds cap")
        }
        return Int(value)
    }

    private mutating func readRaw(_ count: Int) throws -> [UInt8] {
        guard offset + count <= bytes.count else {
            throw MicroCBORError(message: "string extends past end of input")
        }
        defer { offset += count }
        return Array(bytes[offset..<(offset + count)])
    }
}
