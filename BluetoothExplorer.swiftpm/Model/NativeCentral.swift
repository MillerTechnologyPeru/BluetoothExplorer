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
#if canImport(DarwinGATT)
import DarwinGATT
#endif

#if os(Android) || os(iOS) && targetEnvironment(simulator)
public typealias NativeCentral = MockCentral
#elseif canImport(Darwin)
public typealias NativeCentral = DarwinCentral
#else
#error("Platform not supported")
#endif

extension NativeCentral {
    
    /// Wait for CoreBluetooth to be ready.
    func wait(
        warning: Int = 3,
        timeout: Int = 10
    ) async throws {
        
        var powerOnWait = 0
        var currentState: Bool
        repeat {
            currentState = await self.isEnabled
            // inform user after 3 seconds
            if powerOnWait == warning {
                NSLog("Waiting for Bluetooth to be ready, please turn on Bluetooth")
            }
            // sleep for 1s
            try await Task.sleep(for: .seconds(1))
            powerOnWait += 1
            guard powerOnWait < timeout else {
                throw CocoaError(.featureUnsupported) // TODO: Update error
            }
        } while currentState != true
    }
}
