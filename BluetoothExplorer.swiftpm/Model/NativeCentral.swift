//
//  Central.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import SwiftUI
import Bluetooth
import GATT
import DarwinGATT

#if os(iOS) && targetEnvironment(simulator)
typealias NativeCentral = MockCentral

extension NativeCentral {
    
    private struct Cache {
        static let central = MockCentral()
    }
    
    static var shared: NativeCentral {
        return Cache.central
    }
}

#else
typealias NativeCentral = DarwinCentral

extension NativeCentral {
    
    private struct Cache {
        static let central = DarwinCentral(
            options: .init(showPowerAlert: true)
        )
    }
    
    static var shared: NativeCentral {
        return Cache.central
    }
}

#endif
