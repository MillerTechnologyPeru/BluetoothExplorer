//
//  MockService.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

#if DEBUG
import Bluetooth
import GATT

internal typealias MockService = GATT.Service<GATT.Peripheral, UInt16>
internal typealias MockCharacteristic = GATT.Characteristic<GATT.Peripheral, UInt16>
internal typealias MockDescriptor = GATT.Descriptor<GATT.Peripheral, UInt16>

internal extension MockService {
    
    static var deviceInformation: MockService {
        Service(
            id: 10,
            uuid: BluetoothUUID.Service.deviceInformation,
            peripheral: .beacon
        )
    }
    
    static var battery: MockService {
        Service(
            id: 20,
            uuid: BluetoothUUID.Service.battery,
            peripheral: .beacon
        )
    }
    
    static var savantSystems: MockService {
        Service(
            id: 30,
            uuid: BluetoothUUID.Member.savantSystems2,
            peripheral: .smartThermostat
        )
    }
}

internal extension MockCharacteristic {
    
    static var deviceName: MockCharacteristic {
        Characteristic(
            id: 11,
            uuid: BluetoothUUID.Characteristic.deviceName,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var manufacturerName: MockCharacteristic {
        Characteristic(
            id: 12,
            uuid: BluetoothUUID.Characteristic.manufacturerNameString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var modelNumber: MockCharacteristic {
        Characteristic(
            id: 13,
            uuid: BluetoothUUID.Characteristic.modelNumberString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var serialNumber: MockCharacteristic {
        Characteristic(
            id: 14,
            uuid: BluetoothUUID.Characteristic.serialNumberString,
            peripheral: .beacon,
            properties: [.read]
        )
    }
    
    static var batteryLevel: MockCharacteristic {
        Characteristic(
            id: 21,
            uuid: BluetoothUUID.Characteristic.batteryLevel,
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

internal extension MockDescriptor {
    
    static func clientCharacteristicConfiguration(_ peripheral: Peripheral) -> MockDescriptor {
        Descriptor(
            id: 99,
            uuid: BluetoothUUID.Descriptor.clientCharacteristicConfiguration,
            peripheral: peripheral
        )
    }
}

#endif
