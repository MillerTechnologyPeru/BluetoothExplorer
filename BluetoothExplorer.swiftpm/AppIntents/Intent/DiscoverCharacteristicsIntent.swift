//
//  DiscoverServicesIntent.swift
//  
//
//  Created by Alsey Coleman Miller on 11/22/22.
//

import AppIntents
import SwiftUI
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct DiscoverCharacteristicsIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Discover characteristics" }
    
    static var description: IntentDescription {
        IntentDescription(
            "Discover characteristics for a specified service.",
            categoryName: "Utility",
            searchKeywords: ["discovery", "characteristics", "bluetooth"]
        )
    }
    
    @Parameter(
        title: "The specified service.",
        description: "he specified service whose characteristics will be discovered."
    )
    var service: ServiceEntity
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let store = BluetoothExplorerApp.store
        guard let peripheral = store.scanResults.keys.first(where: { $0.id == service.id.peripheral }) else {
            throw CentralError.unknownPeripheral
        }
        guard let service = store.services[peripheral, default: []].first(where: { $0.id.hashValue == service.id.attributeID && $0.peripheral.id == service.id.peripheral }) else {
            throw CentralError.invalidAttribute(BluetoothUUID(rawValue: service.uuid) ?? .bit128(.zero))
        }
        try await store.central.wait(warning: 1, timeout: 2)
        if await store.connected.contains(peripheral) == false {
            try await store.connect(to: peripheral)
        }
        try await store.discoverCharacteristics(for: service)
        await store.disconnect(peripheral)
        let characteristics = store.characteristics[service, default: []].map {
            CharacteristicEntity($0)
        }
        return .result(
            value: characteristics
        )
    }
}
