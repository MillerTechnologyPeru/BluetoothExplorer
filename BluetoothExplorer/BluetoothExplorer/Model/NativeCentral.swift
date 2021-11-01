//
//  Central.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import SwiftUI
import Bluetooth
import GATT
import DarwinGATT

typealias NativeCentral = AsyncDarwinCentral
typealias NativePeripheral = AsyncDarwinCentral.Peripheral
typealias NativeScanData = ScanData<NativePeripheral, DarwinAdvertisementData>

extension NativeCentral {
    
    private struct Cache {
        static let central = NativeCentral(
            options: .init(showPowerAlert: true)
        )
    }
    
    static var shared: NativeCentral {
        return Cache.central
    }
}
