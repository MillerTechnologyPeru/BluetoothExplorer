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

#if os(Android) || os(iOS) && targetEnvironment(simulator)
typealias NativeCentral = MockCentral

extension NativeCentral {
    
    private struct Cache {
        static let central = MockCentral()
    }
    
    static var shared: NativeCentral {
        return Cache.central
    }
}

#elseif canImport(Darwin)
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
#else
#error("Platform not supported")
#endif

#if canImport(Darwin)
public extension NativeCentral {
    
    /// Wait for CoreBluetooth to be ready.
    func wait(
        for state: DarwinBluetoothState,
        warning: Int = 3,
        timeout: Int = 10
    ) async throws {
        
        var powerOnWait = 0
        var currentState: DarwinBluetoothState
        repeat {
            currentState = await self.state
            // inform user after 3 seconds
            if powerOnWait == warning {
                NSLog("Waiting for CoreBluetooth to be ready, please turn on Bluetooth")
            }
            // sleep for 1s
            if #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) {
                try await Task.sleep(for: .seconds(1))
            } else {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            powerOnWait += 1
            guard powerOnWait < timeout else {
                throw DarwinCentralError.invalidState(currentState)
            }
        } while currentState != state
    }
}
#endif
