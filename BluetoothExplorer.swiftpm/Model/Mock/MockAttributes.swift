//
//  MockService.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

#if DEBUG
import SwiftUI
import Bluetooth
import GATT

typealias MockService = GATT.Service<GATT.Peripheral, UInt16>
typealias MockCharacteristic = GATT.Characteristic<GATT.Peripheral, UInt16>
typealias MockDescriptor = GATT.Descriptor<GATT.Peripheral, UInt16>

extension MockService {
    
    static var deviceInformation: MockService {
        Service(
            id: 10,
            uuid: .deviceInformation,
            peripheral: .beacon
        )
    }
    
    static var battery: MockService {
        Service(
            id: 20,
            uuid: .batteryService,
            peripheral: .beacon
        )
    }
    
    static var savantSystems: MockService {
        Service(
            id: 30,
            uuid: .savantSystems2,
            peripheral: .smartThermostat
        )
    }
}

extension MockCharacteristic {
    
    static var deviceName: MockCharacteristic {
        Characteristic(
            id: 11,
            uuid: .deviceName,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var manufacturerName: MockCharacteristic {
        Characteristic(
            id: 12,
            uuid: .manufacturerNameString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var modelNumber: MockCharacteristic {
        Characteristic(
            id: 13,
            uuid: .modelNumberString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var serialNumber: MockCharacteristic {
        Characteristic(
            id: 14,
            uuid: .serialNumberString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var batteryLevel: MockCharacteristic {
        Characteristic(
            id: 21,
            uuid: .batteryLevel,
            peripheral: .beacon,
            properties: [.read, .notify]
        )
    }
    
    static let savantTest: MockCharacteristic = Characteristic(
        id: 31,
        uuid: BluetoothUUID(),
        peripheral: .smartThermostat,
        properties: [.read, .write, .writeWithoutResponse, .notify]
    )
}

extension MockDescriptor {
    
    static func clientCharacteristicConfiguration(_ peripheral: Peripheral) -> MockDescriptor {
        Descriptor(
            id: 99,
            uuid: .clientCharacteristicConfiguration,
            peripheral: peripheral
        )
    }
}

#endif
