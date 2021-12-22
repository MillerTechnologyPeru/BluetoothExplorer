//
//  ServicesList.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct ServicesList: View {
    
    @StateObject
    var store: Store
    
    let peripheral: NativePeripheral
    
    @State
    var isRefreshing = false
    
    var body: some View {
        List {
            ForEach(services) { service in
                NavigationLink(destination: {
                    CharacteristicsList(store: store, service: service)
                }, label: {
                    AttributeCell(uuid: service.uuid)
                })
            }
        }
        .task {
            if services.isEmpty {
                await reload()
            }
        }
        .refreshable {
            await reload()
        }
    }
}

extension ServicesList {
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var services: [NativeService] {
        store.services[peripheral] ?? []
    }
    
    func reload() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.discoverServices(for: peripheral)
        }
        catch { print("Unable to load services", error) }
    }
}
