//
//  Central.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 9/7/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import Bluetooth
import GATT

#if os(macOS) || os(iOS)
import DarwinGATT

typealias NativeCentral = DarwinCentral

private struct CentralCache {
    
    static let options = DarwinCentral.Options(showPowerAlert: false, restoreIdentifier: nil)
    
    static let central = DarwinCentral(options: options)
}

#endif

internal extension NativeCentral {
    
    static var shared: NativeCentral {
        
        return CentralCache.central
    }
}
