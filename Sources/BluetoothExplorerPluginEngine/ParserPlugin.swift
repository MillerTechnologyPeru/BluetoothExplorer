//
//  ParserPlugin.swift
//  BluetoothExplorerPluginEngine
//

import Foundation
import Bluetooth

/// One decode request handed to a plugin.
public struct ParseRequest: Equatable, Sendable {

    public let kind: ParseKind

    /// Company identifier, present when `kind == .manufacturerData`.
    public let companyID: UInt16?

    /// Attribute or service UUID, present for service-data / characteristic / descriptor kinds.
    public let uuid: BluetoothUUID?

    /// Raw payload. For manufacturer data the company ID is already stripped.
    public let payload: Data

    public init(kind: ParseKind, companyID: UInt16? = nil, uuid: BluetoothUUID? = nil, payload: Data) {
        self.kind = kind
        self.companyID = companyID
        self.uuid = uuid
        self.payload = payload
    }
}

/// The keys a plugin is routed on. The registry indexes plugins by these for O(1) lookup.
public struct RoutingKeys: Equatable, Sendable {
    public var companyIdentifiers: [UInt16]
    public var serviceDataUUIDs: [BluetoothUUID]
    public var characteristicUUIDs: [BluetoothUUID]
    public var descriptorUUIDs: [BluetoothUUID]

    public init(
        companyIdentifiers: [UInt16] = [],
        serviceDataUUIDs: [BluetoothUUID] = [],
        characteristicUUIDs: [BluetoothUUID] = [],
        descriptorUUIDs: [BluetoothUUID] = []
    ) {
        self.companyIdentifiers = companyIdentifiers
        self.serviceDataUUIDs = serviceDataUUIDs
        self.characteristicUUIDs = characteristicUUIDs
        self.descriptorUUIDs = descriptorUUIDs
    }
}

/// A parser plugin: native (Swift) or WASM-backed. Implementations must be safe to call from
/// any actor; WASM plugins hop to their own executor internally.
public protocol ParserPlugin: Sendable {

    var id: PluginID { get }

    var name: String { get }

    /// The routing keys this plugin should be invoked for.
    var routingKeys: RoutingKeys { get }

    /// Attempt to decode `request`. Returns `nil` when the plugin does not recognize the data
    /// (not an error). Should not throw for ordinary "not mine" cases.
    func parse(_ request: ParseRequest) async -> DecodedResult?
}
