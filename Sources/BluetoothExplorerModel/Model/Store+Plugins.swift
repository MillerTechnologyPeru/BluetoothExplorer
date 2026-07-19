//
//  Store+Plugins.swift
//  BluetoothExplorerModel
//
//  Bridges the Store's scan / read / notify pipeline to the parser plugin registry. Decoding runs
//  off the main actor (on the plugin executor) and results are written back on the main actor.
//

import Foundation
import Bluetooth
import GATT
import BluetoothExplorerPluginEngine

extension Store {

    /// Decode an advertisement's manufacturer and service data via matching plugins.
    /// A fingerprint skips re-decoding identical repeated advertisements (the common case).
    func decodeAdvertisement(_ cache: ScanResult, for peripheral: Peripheral) {
        var requests = [ParseRequest]()

        if let manufacturerData = cache.manufacturerData {
            requests.append(ParseRequest(
                kind: .manufacturerData,
                companyID: manufacturerData.companyIdentifier.rawValue,
                payload: Data(manufacturerData.additionalData)
            ))
        }
        for (serviceUUID, value) in cache.serviceData {
            requests.append(ParseRequest(kind: .serviceData, uuid: serviceUUID, payload: Data(value)))
        }

        guard requests.isEmpty == false else { return }

        var hasher = Hasher()
        for request in requests {
            hasher.combine(request.kind)
            hasher.combine(request.companyID)
            hasher.combine(request.uuid)
            hasher.combine(request.payload)
        }
        let fingerprint = hasher.finalize()
        guard advertisementFingerprints[peripheral] != fingerprint else { return }
        advertisementFingerprints[peripheral] = fingerprint

        let registry = self.registry
        Task { [weak self] in
            var results = [DecodedResult]()
            for request in requests {
                results.append(contentsOf: await registry.decodeAll(request))
            }
            guard let self else { return }
            self.setDecodedAdvertisement(results, for: peripheral)
        }
    }

    private func setDecodedAdvertisement(_ results: [DecodedResult], for peripheral: Peripheral) {
        if results.isEmpty {
            decodedAdvertisements[peripheral] = nil
        } else {
            decodedAdvertisements[peripheral] = results
        }
    }

    /// Decode a characteristic value via the first matching plugin.
    func decodeCharacteristicValue(_ value: AttributeValue, for characteristic: Characteristic) {
        let registry = self.registry
        let request = ParseRequest(kind: .characteristic, uuid: characteristic.uuid, payload: value.data)
        let valueID = value.id
        Task { [weak self] in
            let result = await registry.decodeFirst(request)
            guard let self, let result else { return }
            self.storeDecoded(result, valueID: valueID, for: characteristic)
        }
    }

    private func storeDecoded(_ result: DecodedResult, valueID: UUID, for characteristic: Characteristic) {
        decodedCharacteristicValues[characteristic, default: [:]][valueID] = result
        // Evict decoded entries whose backing AttributeValue has aged out of the capacity-10 cache.
        if let liveIDs = characteristicValues[characteristic]?.values.map(\.id) {
            let live = Set(liveIDs)
            decodedCharacteristicValues[characteristic] = decodedCharacteristicValues[characteristic]?
                .filter { live.contains($0.key) }
        }
    }

    /// Decode a descriptor value via the first matching plugin.
    func decodeDescriptorValue(_ value: AttributeValue, for descriptor: Descriptor) {
        let registry = self.registry
        let request = ParseRequest(kind: .descriptor, uuid: descriptor.uuid, payload: value.data)
        let valueID = value.id
        Task { [weak self] in
            let result = await registry.decodeFirst(request)
            guard let self, let result else { return }
            self.storeDecoded(result, valueID: valueID, for: descriptor)
        }
    }

    private func storeDecoded(_ result: DecodedResult, valueID: UUID, for descriptor: Descriptor) {
        decodedDescriptorValues[descriptor, default: [:]][valueID] = result
        if let liveIDs = descriptorValues[descriptor]?.values.map(\.id) {
            let live = Set(liveIDs)
            decodedDescriptorValues[descriptor] = decodedDescriptorValues[descriptor]?
                .filter { live.contains($0.key) }
        }
    }
}

// MARK: - Convenience accessors for the UI

public extension Store {

    /// Decoded results for a characteristic value, if any plugin recognized it.
    func decoded(for value: AttributeValue, characteristic: Characteristic) -> DecodedResult? {
        decodedCharacteristicValues[characteristic]?[value.id]
    }

    /// Decoded results for a descriptor value, if any plugin recognized it.
    func decoded(for value: AttributeValue, descriptor: Descriptor) -> DecodedResult? {
        decodedDescriptorValues[descriptor]?[value.id]
    }

    /// Decoded advertisement results for a peripheral.
    func decodedAdvertisement(for peripheral: Peripheral) -> [DecodedResult] {
        decodedAdvertisements[peripheral] ?? []
    }
}
