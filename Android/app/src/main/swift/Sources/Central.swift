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

#elseif os(Android)

import Android
import AndroidUIKit

typealias NativeCentral = AndroidCentral

private struct CentralCache {
    
    static let hostController = Android.Bluetooth.Adapter.default!
    
    static let context = AndroidContext(casting: UIApplication.shared.android)!
    
    static let options = AndroidCentral.Options()
    
    static let central = AndroidCentral(hostController: hostController, context: context, options: options)
}

#endif

internal extension NativeCentral {
    
    static var shared: NativeCentral {
        
        return CentralCache.central
    }
}
