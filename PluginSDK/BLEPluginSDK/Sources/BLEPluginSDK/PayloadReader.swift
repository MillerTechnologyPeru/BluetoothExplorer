//
//  PayloadReader.swift
//  BLEPluginSDK
//
//  An allocation-free cursor over the payload bytes in guest linear memory.
//

public struct PayloadReader {

    private let base: UnsafeRawPointer
    public let count: Int
    public private(set) var offset: Int = 0

    public init(base: UnsafeRawPointer, count: Int) {
        self.base = base
        self.count = count
    }

    /// Bytes not yet consumed.
    public var remaining: Int { count - offset }

    public func byte(at index: Int) -> UInt8? {
        guard index >= 0, index < count else { return nil }
        return base.load(fromByteOffset: index, as: UInt8.self)
    }

    public mutating func readUInt8() -> UInt8? {
        guard remaining >= 1 else { return nil }
        defer { offset += 1 }
        return base.load(fromByteOffset: offset, as: UInt8.self)
    }

    public mutating func readInt8() -> Int8? {
        readUInt8().map { Int8(bitPattern: $0) }
    }

    public mutating func readUInt16BigEndian() -> UInt16? {
        guard remaining >= 2 else { return nil }
        let high = base.load(fromByteOffset: offset, as: UInt8.self)
        let low = base.load(fromByteOffset: offset + 1, as: UInt8.self)
        offset += 2
        return (UInt16(high) << 8) | UInt16(low)
    }

    public mutating func readUInt16LittleEndian() -> UInt16? {
        guard remaining >= 2 else { return nil }
        let low = base.load(fromByteOffset: offset, as: UInt8.self)
        let high = base.load(fromByteOffset: offset + 1, as: UInt8.self)
        offset += 2
        return (UInt16(high) << 8) | UInt16(low)
    }

    public mutating func readUInt32LittleEndian() -> UInt32? {
        guard remaining >= 4 else { return nil }
        var value: UInt32 = 0
        for index in 0..<4 {
            value |= UInt32(base.load(fromByteOffset: offset + index, as: UInt8.self)) << (8 * UInt32(index))
        }
        offset += 4
        return value
    }

    /// Read 16 bytes as a big-endian UUID.
    public mutating func readUUID() -> UUIDBytes? {
        guard remaining >= 16 else { return nil }
        let value = UUIDBytes(loading: base + offset)
        offset += 16
        return value
    }

    /// Consume `length` bytes and pass them to `body`.
    public mutating func readBytes<R>(_ length: Int, _ body: (UnsafeBufferPointer<UInt8>) -> R) -> R? {
        guard length >= 0, remaining >= length else { return nil }
        let buffer = UnsafeBufferPointer(start: (base + offset).assumingMemoryBound(to: UInt8.self), count: length)
        offset += length
        return body(buffer)
    }

    /// A buffer over everything not yet consumed, without advancing.
    public func remainingBytes<R>(_ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        body(UnsafeBufferPointer(start: (base + offset).assumingMemoryBound(to: UInt8.self), count: remaining))
    }
}
