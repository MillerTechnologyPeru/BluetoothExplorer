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

#endif
