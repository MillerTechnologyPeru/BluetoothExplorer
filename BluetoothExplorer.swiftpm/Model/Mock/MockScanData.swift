//
//  MockScanData.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

#if DEBUG
import Foundation
import Bluetooth
import GATT

typealias MockScanData = ScanData<GATT.Peripheral, MockAdvertisementData>

extension MockScanData {
    
    static let beacon = MockScanData(
        peripheral: .beacon,
        date: Date(timeIntervalSinceReferenceDate: 10_000),
        rssi: -20,
        advertisementData: .beacon,
        isConnectable: true
    )
    
    static let smartThermostat = MockScanData(
        peripheral: .smartThermostat,
        date: Date(timeIntervalSinceReferenceDate: 10_100),
        rssi: -127,
        advertisementData: .smartThermostat,
        isConnectable: true
    )
}

extension Peripheral {
    
    static var beacon: Peripheral {
        Peripheral(id: BluetoothAddress(rawValue: "00:AA:AB:03:10:01")!)
    }
    
    static var smartThermostat: Peripheral {
        Peripheral(id: BluetoothAddress(rawValue: "00:1A:7D:DA:71:13")!)
    }
}

#endif
