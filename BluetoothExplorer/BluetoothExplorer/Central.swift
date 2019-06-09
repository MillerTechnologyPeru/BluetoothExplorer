//
//  Central.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import Bluetooth
import GATT
import SwiftUI

typealias Peripheral = NativeCentral.Peripheral

extension NativeCentral.Peripheral: Identifiable {
    
    public var id: Identifier {
        return identifier
    }
}

extension ScanData: Identifiable {
    
    public var id: Peripheral.Identifier {
        return peripheral.identifier
    }
}

extension NativeCentral {
    
    static var shared: NativeCentral {
        return CentralCache.central
    }
}

#if canImport(DarwinGATT)
import DarwinGATT

typealias NativeCentral = DarwinCentral

private struct CentralCache {
    static let options = DarwinCentral.Options(showPowerAlert: false, restoreIdentifier: nil)
    static let central = DarwinCentral(options: options)
}
#endif
