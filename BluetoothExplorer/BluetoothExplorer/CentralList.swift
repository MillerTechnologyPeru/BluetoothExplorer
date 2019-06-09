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
    
    @EnvironmentObject private var store: Store
    
    var scanResults: [ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>] {
        return store.scanResults.values.sorted(by: { $0.peripheral.description < $1.peripheral.description })
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(scanResults) {
                    Text(verbatim: $0.advertisementData.localName ?? $0.peripheral.description)
                }
            }
            .navigationBarTitle(Text("Central"), displayMode: .large)
            .navigationBarItems(trailing: Navigation)
        }
    }
}

extension CentralList {
    
    var leftBarButtonItem: some View {
        if store.operationState == .scanning {
            return Button(action: { self.store.stopScanning() }) {
                Text("Stop")
            }
        } else {
            return Button(action: { self.store.scan() }) {
                Text("Scan")
            }
        }
    }
}

#if DEBUG
extension CentralList : PreviewProvider {
    static var previews: some View {
        CentralList()
    }
}
#endif
