//
//  BluetoothUUID.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import Bluetooth

internal extension BluetoothUUID {
    
    func description(for value: Data) -> String? {
        switch self {
        case BluetoothUUID.Characteristic.batteryLevel:
            return value.first.flatMap { $0.description + "%" }
        case BluetoothUUID.Characteristic.currentTime:
            return nil
        case BluetoothUUID.Characteristic.deviceName,
            BluetoothUUID.Characteristic.serialNumberString,
            BluetoothUUID.Characteristic.firmwareRevisionString,
            BluetoothUUID.Characteristic.softwareRevisionString,
            BluetoothUUID.Characteristic.hardwareRevisionString,
            BluetoothUUID.Characteristic.modelNumberString,
            BluetoothUUID.Characteristic.manufacturerNameString:
            return String(data: value, encoding: .utf8)
        default:
            return nil
        }
    }
}
