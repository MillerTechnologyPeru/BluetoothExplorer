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
public enum DecodedValue: Equatable, Hashable, Sendable {
    case string(String)
    case int(Int64)
    case uint(UInt64)
    case double(Double)
    case bool(Bool)
    /// Raw bytes; rendered as hexadecimal by the UI.
    case bytes(Data)
    case uuid(UUID)
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
