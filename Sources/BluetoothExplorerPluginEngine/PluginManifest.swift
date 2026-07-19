//
//  PluginManifest.swift
//  BluetoothExplorerPluginEngine
//
//  Codable model for a plugin's JSON sidecar manifest, plus routing keys.
//

import Foundation
import Bluetooth

/// A plugin's metadata sidecar (`<name>.bleplugin.json`).
public struct PluginManifest: Codable, Equatable, Sendable, Identifiable {

    public var id: PluginID { PluginID(identifier) }

    /// Manifest schema version.
    public let manifestVersion: Int

    /// Reverse-DNS plugin identifier.
    public let identifier: String

    /// Human-readable name.
    public let name: String

    /// Semantic version of the plugin.
    public let version: String

    /// ABI major version the plugin targets.
    public let abi: Int

    /// The `.wasm` file name relative to the manifest.
    public let module: String

    /// Lowercase hex SHA-256 of the module bytes. Required for imported plugins.
    public let sha256: String?

    /// Routing rules.
    public let matches: Matches

    /// Optional resource limits.
    public let limits: Limits?

    private enum CodingKeys: String, CodingKey {
        case manifestVersion
        case identifier = "id"
        case name
        case version
        case abi
        case module
        case sha256
        case matches
        case limits
    }

    public struct Matches: Codable, Equatable, Sendable {
        public var companyIdentifiers: [UInt16]
        public var serviceDataUUIDs: [String]
        public var characteristicUUIDs: [String]
        public var descriptorUUIDs: [String]

        public init(
            companyIdentifiers: [UInt16] = [],
            serviceDataUUIDs: [String] = [],
            characteristicUUIDs: [String] = [],
            descriptorUUIDs: [String] = []
        ) {
            self.companyIdentifiers = companyIdentifiers
            self.serviceDataUUIDs = serviceDataUUIDs
            self.characteristicUUIDs = characteristicUUIDs
            self.descriptorUUIDs = descriptorUUIDs
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            companyIdentifiers = try container.decodeIfPresent([UInt16].self, forKey: .companyIdentifiers) ?? []
            serviceDataUUIDs = try container.decodeIfPresent([String].self, forKey: .serviceDataUUIDs) ?? []
            characteristicUUIDs = try container.decodeIfPresent([String].self, forKey: .characteristicUUIDs) ?? []
            descriptorUUIDs = try container.decodeIfPresent([String].self, forKey: .descriptorUUIDs) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case companyIdentifiers, serviceDataUUIDs, characteristicUUIDs, descriptorUUIDs
        }
    }

    public struct Limits: Codable, Equatable, Sendable {
        public var maxMemoryPages: Int?
        public var maxOutputBytes: Int?

        public init(maxMemoryPages: Int? = nil, maxOutputBytes: Int? = nil) {
            self.maxMemoryPages = maxMemoryPages
            self.maxOutputBytes = maxOutputBytes
        }
    }

    public init(
        manifestVersion: Int = 1,
        identifier: String,
        name: String,
        version: String,
        abi: Int = PluginABI.version,
        module: String,
        sha256: String? = nil,
        matches: Matches,
        limits: Limits? = nil
    ) {
        self.manifestVersion = manifestVersion
        self.identifier = identifier
        self.name = name
        self.version = version
        self.abi = abi
        self.module = module
        self.sha256 = sha256
        self.matches = matches
        self.limits = limits
    }
}

public extension PluginManifest {

    /// The set of parse capabilities this manifest declares, based on its non-empty match lists.
    var declaredCapabilities: Set<ParseKind> {
        var result = Set<ParseKind>()
        if !matches.companyIdentifiers.isEmpty { result.insert(.manufacturerData) }
        if !matches.serviceDataUUIDs.isEmpty { result.insert(.serviceData) }
        if !matches.characteristicUUIDs.isEmpty { result.insert(.characteristic) }
        if !matches.descriptorUUIDs.isEmpty { result.insert(.descriptor) }
        return result
    }

    /// Parsed service-data routing UUIDs (invalid strings dropped).
    var serviceDataBluetoothUUIDs: [BluetoothUUID] {
        matches.serviceDataUUIDs.compactMap { BluetoothUUID(rawValue: $0) }
    }

    /// Parsed characteristic routing UUIDs (invalid strings dropped).
    var characteristicBluetoothUUIDs: [BluetoothUUID] {
        matches.characteristicUUIDs.compactMap { BluetoothUUID(rawValue: $0) }
    }

    /// Parsed descriptor routing UUIDs (invalid strings dropped).
    var descriptorBluetoothUUIDs: [BluetoothUUID] {
        matches.descriptorUUIDs.compactMap { BluetoothUUID(rawValue: $0) }
    }

    /// Effective guest linear-memory cap, in bytes.
    var maxMemoryBytes: Int {
        let pages = min(limits?.maxMemoryPages ?? PluginABI.defaultMaxMemoryPages, PluginABI.maxMemoryPagesCeiling)
        return pages * 64 * 1024
    }

    /// Effective output cap, in bytes.
    var maxOutputBytes: Int {
        limits?.maxOutputBytes ?? PluginABI.defaultMaxOutputBytes
    }

    /// Validate structural invariants of the manifest.
    func validate() throws {
        guard abi == PluginABI.version else {
            throw PluginError.unsupportedABI(found: abi, supported: PluginABI.version)
        }
        guard declaredCapabilities.isEmpty == false else {
            throw PluginError.invalidModule("manifest declares no matches")
        }
    }
}
