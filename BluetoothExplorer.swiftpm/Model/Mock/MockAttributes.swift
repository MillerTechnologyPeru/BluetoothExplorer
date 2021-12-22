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
            id: 0,
            uuid: .deviceInformation,
            peripheral: .beacon
        )
    }
}

extension MockCharacteristic {
    
    static var deviceName: MockCharacteristic {
        Characteristic(
            id: 1,
            uuid: .deviceName,
            peripheral: .beacon,
            properties: [.read]
        )
    }
}

extension MockDescriptor {
    
    static var clientCharacteristicConfiguration: MockDescriptor {
        Descriptor(
            id: 3,
            uuid: .clientCharacteristicConfiguration,
            peripheral: .beacon
        )
    }
}

#endif
