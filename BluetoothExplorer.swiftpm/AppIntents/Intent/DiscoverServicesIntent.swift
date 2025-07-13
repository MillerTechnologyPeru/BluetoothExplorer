//
//  DiscoverServicesIntent.swift
//  
//
//  Created by Alsey Coleman Miller on 11/22/22.
//

#if canImport(AppIntents) && canImport(SwiftUI)
import AppIntents
import SwiftUI
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct DiscoverServicesIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Discover services" }
    
    static var description: IntentDescription {
        IntentDescription(
            "Discover services for a specified device.",
            categoryName: "Utility",
            searchKeywords: ["discovery", "services", "bluetooth"]
        )
    }
    
    @Parameter(
        title: "The Bluetooth device to connect to.",
        description: "The device to connect to."
    )
    var device: PeripheralEntity
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let store = BluetoothExplorerApp.store
        guard let peripheral = store.scanResults.keys.first(where: { $0.id == device.id }) else {
            throw CentralError.unknownPeripheral
        }
        try await store.central.wait(warning: 1, timeout: 2)
        if await store.connected.contains(peripheral) == false {
            try await store.connect(to: peripheral)
        }
        try await store.discoverServices(for: peripheral)
        await store.disconnect(peripheral)
        let services = store.services[peripheral, default: []].map {
            ServiceEntity($0)
        }
        return .result(
            value: services
        )
    }
}
#endif
