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
        .navigationTitle("Service")
        .task {
            if characteristics.isEmpty {
                await reload()
            }
        }
        .refreshable {
            await reload()
        }
    }
}

extension CharacteristicsList {
    
    var peripheral: NativePeripheral {
        service.peripheral
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var characteristics: [NativeCharacteristic] {
        store.characteristics[service] ?? []
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
