//
//  PluginID.swift
//  BluetoothExplorerPluginEngine
//

import Foundation

/// A stable plugin identifier, conventionally reverse-DNS (e.g. `"org.pureswift.plugin.ibeacon"`).
public struct PluginID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

/// Errors raised while loading or executing a plugin.
public enum PluginError: Error, Equatable, Sendable {
    /// The WASM module could not be parsed or is structurally invalid.
    case invalidModule(String)
    /// The module imports host functions, which are not permitted in ABI v1.
    case disallowedImport(module: String, name: String)
    /// The manifest declares an ABI major version the host does not support.
    case unsupportedABI(found: Int, supported: Int)
    /// A capability declared in the manifest has no matching export.
    case capabilityNotExported(String)
    /// A required export (marker, alloc, memory) is missing.
    case missingExport(String)
    /// The module bytes did not match the manifest `sha256`.
    case hashMismatch
    /// The module file exceeded the maximum permitted size.
    case moduleTooLarge(bytes: Int, limit: Int)
    /// The guest trapped during execution.
    case trap(String)
    /// The guest allocator returned a null pointer.
    case allocationFailed
    /// The guest returned a result region outside its linear memory, or larger than allowed.
    case invalidResultRegion
    /// The output exceeded `maxOutputBytes`.
    case outputTooLarge(bytes: Int, limit: Int)
    /// The output could not be decoded as the expected CBOR envelope.
    case malformedOutput(String)
    /// The call exceeded its wall-clock deadline and the plugin was quarantined.
    case deadlineExceeded
    /// The plugin was disabled after repeated failures.
    case quarantined
}
