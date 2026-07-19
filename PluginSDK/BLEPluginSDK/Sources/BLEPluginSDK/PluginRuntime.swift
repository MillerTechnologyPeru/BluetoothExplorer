//
//  PluginRuntime.swift
//  BLEPluginSDK
//
//  The glue a plugin's export shims call. Handles guest allocation and the packed
//  (pointer << 32) | length return convention.
//

public enum PluginRuntime {

    /// Backing for the `bleplug_alloc` export. Returns a linear-memory offset, or 0 on failure.
    public static func allocate(_ size: UInt32) -> UInt32 {
        guard size > 0 else { return 0 }
        let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<UInt64>.alignment
        )
        return UInt32(UInt(bitPattern: pointer))
    }

    /// Backing for the `bleplug_free` export.
    public static func deallocate(_ pointer: UInt32) {
        guard pointer != 0, let raw = UnsafeMutableRawPointer(bitPattern: UInt(pointer)) else { return }
        raw.deallocate()
    }

    /// Decode the envelope, run `parse`, and encode the result.
    ///
    /// Returns `0` when the plugin does not recognize the input — the host treats that as
    /// "not mine", not an error.
    public static func handle(
        pointer: UInt32,
        length: UInt32,
        parse: (ParseInput) -> Fields?
    ) -> UInt64 {
        guard pointer != 0, let base = UnsafeRawPointer(bitPattern: UInt(pointer)) else { return 0 }
        guard let input = ParseInput(pointer: base, length: length) else { return 0 }
        guard let fields = parse(input), fields.isEmpty == false else { return 0 }

        let encoded = fields.encode()
        guard encoded.isEmpty == false else { return 0 }

        let outputPointer = allocate(UInt32(encoded.count))
        guard outputPointer != 0,
              let raw = UnsafeMutableRawPointer(bitPattern: UInt(outputPointer))
        else { return 0 }

        let bytes = raw.bindMemory(to: UInt8.self, capacity: encoded.count)
        for index in encoded.indices {
            bytes[index] = encoded[index]
        }
        return (UInt64(outputPointer) << 32) | UInt64(encoded.count)
    }
}
