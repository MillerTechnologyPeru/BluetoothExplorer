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
    
    @StateObject
    var store: Store
    
    var scanResults: [ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>] {
        return store.scanResults.values.sorted(by: { $0.peripheral.description < $1.peripheral.description })
    }
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            list
            .navigationBarTitle(Text("Central"), displayMode: .automatic)
            .navigationBarItems(trailing: leftBarButtonItem)
        }
        #elseif os(macOS)
        NavigationView {
            VStack {
                leftBarButtonItem
                list
            }
        }
        .navigationTitle(Text("Central"))
        #endif
    }
}

extension CentralList {
    
    var list: some View {
        List {
            ForEach(scanResults) {
                Text(verbatim: $0.advertisementData.localName ?? $0.peripheral.description)
            }
        }
    }
    
    var leftBarButtonItem: some View {
        if store.isScanning {
            return Button(action: {
                Task {
                    await self.store.stopScan()
                }
            }) {
                Text("Stop")
            }
        } else {
            return Button(action: {
                Task {
                    do { try await self.store.scan() }
                    catch { print(error) }
                }
            }) {
                Text("Scan")
            }
        }
    }
}

#if DEBUG
struct CentralList_Preview: PreviewProvider {
    static var previews: some View {
        CentralList(store: .shared)
    }
}
#endif
