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

typealias NativeCentral = DarwinCentral
typealias NativePeripheral = DarwinCentral.Peripheral
typealias NativeScanData = ScanData<NativePeripheral, DarwinAdvertisementData>
typealias NativeService = Service<DarwinCentral.Peripheral, ObjectIdentifier>
typealias NativeCharacteristic = Characteristic<DarwinCentral.Peripheral, ObjectIdentifier>

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
