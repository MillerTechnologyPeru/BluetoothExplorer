//
//  MockAdvertisement.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

#if DEBUG
import Foundation
import Bluetooth
import GATT

/// Mock Advertisement Data
struct MockAdvertisementData: AdvertisementData {
    
    /// The local name of a peripheral.
    let localName: String?
    
    /// The Manufacturer data of a peripheral.
    let manufacturerData: ManufacturerSpecificData?
    
    /// This value is available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    let txPowerLevel: Double?
    
    /// Service-specific advertisement data.
    let serviceData: [BluetoothUUID: Data]?
    
    /// An array of service UUIDs
    let serviceUUIDs: [BluetoothUUID]?
    
    /// An array of one or more `BluetoothUUID`, representing Service UUIDs.
    let solicitedServiceUUIDs: [BluetoothUUID]?
    
    init(localName: String? = nil,
         manufacturerData: ManufacturerSpecificData? = nil,
         txPowerLevel: Double? = nil,
         serviceData: [BluetoothUUID : Data]? = nil,
         serviceUUIDs: [BluetoothUUID]? = nil,
         solicitedServiceUUIDs: [BluetoothUUID]? = nil) {
        
        self.localName = localName
        self.manufacturerData = manufacturerData
        self.txPowerLevel = txPowerLevel
        self.serviceData = serviceData
        self.serviceUUIDs = serviceUUIDs
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
    }
}

extension MockAdvertisementData {
    
    static let beacon = MockAdvertisementData(
        localName: "iBeacon",
        manufacturerData: nil /*AppleBeacon(
            uuid: UUID(),
            rssi: -20
        ).manufacturerData*/,
        txPowerLevel: nil,
        serviceData: nil,
        serviceUUIDs: nil,
        solicitedServiceUUIDs: nil
    )
}

#endif
