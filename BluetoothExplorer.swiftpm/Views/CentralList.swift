//
//  CentralList.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import Bluetooth
import GATT

struct CentralList: View {
    
    @EnvironmentObject
    var store: Store
    
    var scanResults: [Store.ScanData] {
        return store.scanResults.values.sorted(by: { $0.peripheral.description < $1.peripheral.description })
    }
    
    var body: some View {
        list
            .navigationTitle(Text("Central"))
            .toolbar { leftBarButtonItem }
    }
}

extension CentralList {
    
    var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(scanResults) { scanData in
                    NavigationLink(
                        destination: { PeripheralView(peripheral: scanData.peripheral) },
                        label: { CentralCell(name: store.nameCache[scanData.peripheral], scanData: scanData) }
                    )
                }
            }
        }
    }
    
    var leftBarButtonItem: some View {
        switch store.state {
        case .unknown:
            return AnyView(EmptyView())
        case .poweredOff,
             .resetting,
             .unauthorized,
             .unsupported:
            return AnyView(
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            )
        case .poweredOn:
            if store.isScanning {
                return AnyView(Button(action: {
                    Task {
                        await self.store.stopScan()
                    }
                }) {
                    Text("Stop")
                })
            } else {
                return AnyView(Button(action: {
                    Task {
                        do { try await self.store.scan() }
                        catch { print("Error scanning:", error) }
                    }
                }) {
                    Text("Scan")
                })
            }
        }
    }
}

#if DEBUG
struct CentralList_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                CentralList()
            }
            .environmentObject(Store.shared)
        }
    }
}
#endif
