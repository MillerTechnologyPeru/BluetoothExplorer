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
        ServicesList(store: store, peripheral: peripheral)
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
    
    var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    var leftBarButtonItem: some View {
        if showActivity {
            return AnyView(
                ProgressView()
                    .progressViewStyle(.circular)
            )
        } else if isConnected {
            return AnyView(Button(action: {
                assert(Thread.isMainThread)
                store.disconnect(peripheral)
            }) {
                Text("Disconnect")
            })
        } else {
            return AnyView(Button(action: {
                Task {
                    assert(Thread.isMainThread)
                    await connect()
                    assert(Thread.isMainThread)
                }
            }) {
                Text("Connect")
            })
        }
    }
    
    func connect() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
        }
        catch {
            print("Unable to connect", error)
            return
        }
    }
}
