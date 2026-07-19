//
//  DecodedResultCBOR.swift
//  BluetoothExplorerPluginEngine
//
//  Maps the strict CBOR output envelope into a typed `DecodedResult`.
//
//  Output schema (integer-keyed CBOR):
//    { 0: summary?(text), 1: [ { 0: key(text), 1: label(text), 2: value, 3: unit?(text) } ] }
//  value ::= tstr | uint | negative | float64 | bool | bstr(bytes) | tag37 bstr(uuid)
//

import Foundation

extension DecodedResult {

    /// Decode a plugin's CBOR output buffer into a `DecodedResult`.
    static func decode(cbor bytes: [UInt8], pluginID: PluginID) throws -> DecodedResult {
        let root: CBORValue
        do {
            root = try MicroCBOR.decode(bytes)
        } catch let error as MicroCBORError {
            throw PluginError.malformedOutput(error.message)
        }

        guard case let .map(pairs) = root else {
            throw PluginError.malformedOutput("output root is not a map")
        }

        var title: String?
        var fields = [DecodedField]()

        for (key, value) in pairs {
            guard case let .uint(intKey) = key else {
                throw PluginError.malformedOutput("non-integer map key")
            }
            switch intKey {
            case 0:
                if case let .text(text) = value { title = text }
            case 1:
                guard case let .array(items) = value else {
                    throw PluginError.malformedOutput("fields (key 1) is not an array")
                }
                for item in items {
                    fields.append(try decodeField(item))
                }
            default:
                break // ignore unknown keys for forward compatibility
            }
        }

        return DecodedResult(pluginID: pluginID, title: title, fields: fields)
    }

    private static func decodeField(_ value: CBORValue) throws -> DecodedField {
        guard case let .map(pairs) = value else {
            throw PluginError.malformedOutput("field is not a map")
        }
        var key: String?
        var label: String?
        var decodedValue: DecodedValue?
        var unit: String?

        for (mapKey, mapValue) in pairs {
            guard case let .uint(intKey) = mapKey else {
                throw PluginError.malformedOutput("non-integer field key")
            }
            switch intKey {
            case 0:
                if case let .text(text) = mapValue { key = text }
            case 1:
                if case let .text(text) = mapValue { label = text }
            case 2:
                decodedValue = try decodeValue(mapValue)
            case 3:
                if case let .text(text) = mapValue { unit = text }
            default:
                break
            }
        }

        guard let key, let decodedValue else {
            throw PluginError.malformedOutput("field missing key or value")
        }
        return DecodedField(key: key, label: label ?? key, value: decodedValue, unit: unit)
    }

    private static func decodeValue(_ value: CBORValue) throws -> DecodedValue {
        switch value {
        case let .text(text):
            return .string(text)
        case let .uint(number):
            return .uint(number)
        case let .negative(number):
            return .int(number)
        case let .double(number):
            return .double(number)
        case let .bool(flag):
            return .bool(flag)
        case let .bytes(raw):
            return .bytes(Data(raw))
        case let .uuid(raw):
            let tuple = (raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7],
                         raw[8], raw[9], raw[10], raw[11], raw[12], raw[13], raw[14], raw[15])
            return .uuid(UUID(uuid: tuple))
        case .array, .map, .null:
            throw PluginError.malformedOutput("unsupported value type in field")
        }
    }
}
