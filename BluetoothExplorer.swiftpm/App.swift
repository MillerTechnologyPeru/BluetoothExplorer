//
//  App.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import SwiftUI

@main
struct BluetoothExplorerApp: App {
    
    let store = Store.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                CentralList(store: store)
                Text("Scan for devices")
            }.task {
                for await message in NativeCentral.shared.log {
                    print("Central: \(message)")
                }
            }
        }
    }
}
