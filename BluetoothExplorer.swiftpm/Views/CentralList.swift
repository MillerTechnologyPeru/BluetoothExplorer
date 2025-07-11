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
    
    @Environment(Store.self)
    var store: Store
    
    var scanResults: [Store.ScanResult] {
        store.scanResults
            .values
            .sorted(by: { $0.id.description < $1.id.description })
            .sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
            .sorted(by: { $0.name != nil && $1.name == nil })
            .sorted(by: { $0.beacon != nil && $1.beacon == nil })
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
                ForEach(scanResults) { item in
                    NavigationLink(
                        destination: { PeripheralView(peripheral: item.scanData.peripheral) },
                        label: { CentralCell(scanData: item) }
                    )
                }
            }
        }
    }
    
    var leftBarButtonItem: some View {
        switch store.isEnabled {
        case false:
            return AnyView(
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            )
        case true:
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
            .environment(Store())
        }
    }
}
#endif
