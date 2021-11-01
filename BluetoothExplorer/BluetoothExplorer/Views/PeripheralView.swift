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
        if let scanData = store.scanResults[peripheral] {
            ScanDataView(scanData: scanData)
        }
    }
}
