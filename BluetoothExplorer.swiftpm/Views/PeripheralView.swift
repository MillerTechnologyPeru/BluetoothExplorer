//
//  PeripheralView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import Bluetooth
import GATT

struct PeripheralView: View {
    
    @StateObject
    var store: Store
    
    let peripheral: NativePeripheral
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            if let scanData = store.scanResults[peripheral] {
                ScanDataView(scanData: scanData)
            }
            if services.isEmpty == false {
                ServicesList(store: store, peripheral: peripheral)
            }
            Spacer()
        }
        .navigationTitle(title)
        .navigationBarItems(trailing: leftBarButtonItem)
    }
}

extension PeripheralView {
    
    var title: String {
        store.scanResults[peripheral]?.advertisementData.localName ?? "Device"
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var services: [NativeService] {
        store.services[peripheral] ?? []
    }
    
    var leftBarButtonItem: some View {
        if isConnected {
            return Button(action: {
                store.disconnect(peripheral)
            }) {
                Text("Disconnect")
            }
        } else {
            return Button(action: {
                Task {
                    do {
                        try await self.store.connect(to: peripheral)
                        try await self.store.discoverServices(for: peripheral)
                    }
                    catch { print("Error connecting:", error) }
                }
            }) {
                Text("Connect")
            }
        }
    }
}
