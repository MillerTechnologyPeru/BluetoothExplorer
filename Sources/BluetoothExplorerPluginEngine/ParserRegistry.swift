//
//  ParserRegistry.swift
//  BluetoothExplorerPluginEngine
//
//  An immutable routing snapshot over a set of plugins. Rebuilt and swapped by PluginManager.
//

import Foundation
import Bluetooth

/// Immutable routing table. Look-ups are exact-key dictionary hits, so a request that no plugin
/// claims costs ~nothing — important because advertisement decoding runs on the scan path.
public final class ParserRegistry: @unchecked Sendable {

    private let plugins: [PluginID: any ParserPlugin]
    private let order: [PluginID]

    private let byCompany: [UInt16: [PluginID]]
    private let byServiceData: [BluetoothUUID: [PluginID]]
    private let byCharacteristic: [BluetoothUUID: [PluginID]]
    private let byDescriptor: [BluetoothUUID: [PluginID]]

    public init(plugins: [any ParserPlugin]) {
        var pluginMap = [PluginID: any ParserPlugin]()
        var order = [PluginID]()
        var byCompany = [UInt16: [PluginID]]()
        var byServiceData = [BluetoothUUID: [PluginID]]()
        var byCharacteristic = [BluetoothUUID: [PluginID]]()
        var byDescriptor = [BluetoothUUID: [PluginID]]()

        for plugin in plugins {
            let id = plugin.id
            guard pluginMap[id] == nil else { continue } // first registration wins on id collision
            pluginMap[id] = plugin
            order.append(id)
            let keys = plugin.routingKeys
            for company in keys.companyIdentifiers { byCompany[company, default: []].append(id) }
            for uuid in keys.serviceDataUUIDs { byServiceData[uuid, default: []].append(id) }
            for uuid in keys.characteristicUUIDs { byCharacteristic[uuid, default: []].append(id) }
            for uuid in keys.descriptorUUIDs { byDescriptor[uuid, default: []].append(id) }
        }

        self.plugins = pluginMap
        self.order = order
        self.byCompany = byCompany
        self.byServiceData = byServiceData
        self.byCharacteristic = byCharacteristic
        self.byDescriptor = byDescriptor
    }

    /// All registered plugin identifiers, in registration order.
    public var pluginIDs: [PluginID] { order }

    // MARK: Routing

    /// Plugins that claim the given manufacturer company identifier.
    public func plugins(forCompany company: UInt16) -> [PluginID] {
        byCompany[company] ?? []
    }

    private func candidates(for request: ParseRequest) -> [PluginID] {
        switch request.kind {
        case .manufacturerData:
            return request.companyID.flatMap { byCompany[$0] } ?? []
        case .serviceData:
            return request.uuid.flatMap { byServiceData[$0] } ?? []
        case .characteristic:
            return request.uuid.flatMap { byCharacteristic[$0] } ?? []
        case .descriptor:
            return request.uuid.flatMap { byDescriptor[$0] } ?? []
        }
    }

    // MARK: Decoding

    /// Run all matching plugins for the request and collect their non-nil results.
    public func decodeAll(_ request: ParseRequest) async -> [DecodedResult] {
        let candidates = candidates(for: request)
        guard candidates.isEmpty == false else { return [] }
        var results = [DecodedResult]()
        for id in candidates {
            guard let plugin = plugins[id] else { continue }
            if let result = await plugin.parse(request) {
                results.append(result)
            }
        }
        return results
    }

    /// Run matching plugins and return the first non-nil result.
    public func decodeFirst(_ request: ParseRequest) async -> DecodedResult? {
        let candidates = candidates(for: request)
        for id in candidates {
            guard let plugin = plugins[id] else { continue }
            if let result = await plugin.parse(request) {
                return result
            }
        }
        return nil
    }
}
