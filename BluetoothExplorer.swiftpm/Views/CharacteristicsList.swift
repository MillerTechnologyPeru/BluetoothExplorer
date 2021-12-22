//
//  CharacteristicsList.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct CharacteristicsList: View {
    
    @StateObject
    var store: Store
    
    let service: NativeService
    
    @State
    var isRefreshing = false
    
    var body: some View {
        List {
            ForEach(characteristics) { characteristic in
                NavigationLink(destination: {
                    Text(characteristic.uuid.description)
                }, label: {
                    AttributeCell(uuid: characteristic.uuid)
                })
            }
        }
        .navigationTitle(title)
        .navigationBarItems(trailing: leftBarButtonItem)
        .task {
            if characteristics.isEmpty {
                await reload()
            }
        }
        .refreshable {
            isRefreshing = true
            await reload()
            isRefreshing = false
        }
    }
}

extension CharacteristicsList {
    
    var title: String {
        service.uuid.name ?? "Service"
    }
    
    var peripheral: NativePeripheral {
        service.peripheral
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var characteristics: [NativeCharacteristic] {
        store.characteristics[service] ?? []
    }
    
    var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    var leftBarButtonItem: some View {
        if showActivity, isRefreshing == false {
            return AnyView(
                ProgressView()
                    .progressViewStyle(.circular)
            )
        } else {
            return AnyView(
                EmptyView()
            )
        }
    }
    
    func reload() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.discoverCharacteristics(for: service)
        }
        catch { print("Unable to load characteristics", error) }
    }
}
