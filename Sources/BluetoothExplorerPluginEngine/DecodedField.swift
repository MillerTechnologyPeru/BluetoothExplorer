//
//  DecodedField.swift
//  BluetoothExplorerPluginEngine
//
//  Structured output produced by a parser plugin (native or WASM).
//

import Foundation

/// A single decoded field: a stable machine `key`, a human `label`, a typed `value`,
/// and an optional `unit`.
public struct DecodedField: Equatable, Hashable, Sendable, Identifiable {

    public var id: String { key }

    /// Stable machine-readable key, e.g. `"major"`.
    public let key: String

    /// Human-readable label, e.g. `"Major"`.
    public let label: String

    /// The decoded value.
    public let value: DecodedValue

    /// Optional unit, e.g. `"%"`, `"bpm"`, `"dBm"`.
    public let unit: String?

    public init(key: String, label: String, value: DecodedValue, unit: String? = nil) {
        self.key = key
        self.label = label
        self.value = value
        self.unit = unit
    }
}

/// A typed decoded value. Mirrors the value types carried across the WASM ABI (CBOR).
public enum DecodedValue: Sendable {
    case string(String)
    case int(Int64)
    case uint(UInt64)
    case double(Double)
    case bool(Bool)
    /// Raw bytes; rendered as hexadecimal by the UI.
    case bytes(Data)
    case uuid(UUID)
}

extension DecodedValue: Equatable, Hashable {

    /// Integers compare numerically across `int` and `uint`.
    ///
    /// CBOR has no notion of signedness: major type 0 encodes *any* non-negative integer, so a
    /// plugin field that is semantically signed arrives as `uint` whenever its value happens to be
    /// non-negative. The cases therefore mean "negative" and "non-negative", not "signed" and
    /// "unsigned", and two producers of the same number — a native parser and a WASM plugin — must
    /// compare equal. The UI renders both identically.
    public static func == (lhs: DecodedValue, rhs: DecodedValue) -> Bool {
        switch (lhs, rhs) {
        case let (.string(a), .string(b)): return a == b
        case let (.int(a), .int(b)): return a == b
        case let (.uint(a), .uint(b)): return a == b
        case let (.int(a), .uint(b)): return a >= 0 && UInt64(a) == b
        case let (.uint(a), .int(b)): return b >= 0 && a == UInt64(b)
        case let (.double(a), .double(b)): return a == b
        case let (.bool(a), .bool(b)): return a == b
        case let (.bytes(a), .bytes(b)): return a == b
        case let (.uuid(a), .uuid(b)): return a == b
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .string(value):
            hasher.combine(0); hasher.combine(value)
        // Both integer cases share a discriminator, and non-negative values hash through the same
        // UInt64 path, so numerically equal values hash equally as Hashable requires.
        case let .int(value):
            hasher.combine(1)
            if value >= 0 { hasher.combine(UInt64(value)) } else { hasher.combine(value) }
        case let .uint(value):
            hasher.combine(1); hasher.combine(value)
        case let .double(value):
            hasher.combine(2); hasher.combine(value)
        case let .bool(value):
            hasher.combine(3); hasher.combine(value)
        case let .bytes(value):
            hasher.combine(4); hasher.combine(value)
        case let .uuid(value):
            hasher.combine(5); hasher.combine(value)
        }
    }
}

/// The result of a plugin decoding one advertisement field or attribute value.
public struct DecodedResult: Equatable, Hashable, Sendable {

    /// Identifier of the plugin that produced this result.
    public let pluginID: PluginID

    /// One-line human summary, suitable for a list cell (e.g. `"iBeacon"`).
    public let title: String?

    /// The decoded fields, in display order.
    public let fields: [DecodedField]

    public init(pluginID: PluginID, title: String?, fields: [DecodedField]) {
        self.pluginID = pluginID
        self.title = title
        self.fields = fields
    }
}

extension DecodedValue {

    /// A default human-readable rendering used by simple UI paths.
    public var displayString: String {
        switch self {
        case let .string(value):
            return value
        case let .int(value):
            return value.description
        case let .uint(value):
            return value.description
        case let .double(value):
            return value.description
        case let .bool(value):
            return value ? "true" : "false"
        case let .bytes(value):
            return "0x" + value.map { byte in
                let hex = String(byte, radix: 16, uppercase: true)
                return hex.count == 1 ? "0" + hex : hex
            }.joined()
        case let .uuid(value):
            return value.uuidString
        }
    }
}
