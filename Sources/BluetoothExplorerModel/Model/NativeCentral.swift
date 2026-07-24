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

// On Android the real central is `AndroidCentral` from PureSwift/AndroidBluetooth, but that package
// currently cannot be resolved into this app: AndroidBluetooth's `master` pins Bluetooth 7.2.x while
// GATT's `master` has moved to Bluetooth 8.x, and the app's SwiftUI-for-Android layer is itself
// blocked upstream (see Documentation/AndroidSwiftUIMigration.md). Until that settles, Android falls
// back to `MockCentral` so the app is self-consistent; swap `NativeCentral` back to `AndroidCentral`
// (and restore the `AndroidBluetooth` dependency and import) once the upstream versions align.
#if os(iOS) && targetEnvironment(simulator)
public typealias NativeCentral = MockCentral
#elseif canImport(Darwin)
public typealias NativeCentral = DarwinCentral
#elseif os(Android)
public typealias NativeCentral = MockCentral
#else
#warning("Platform not supported")
public typealias NativeCentral = MockCentral
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

#if canImport(Darwin)
extension DarwinCentral {
    
    var isEnabled: Bool {
        get async {
            await self.state == .poweredOn
        }
    }
}
#endif
