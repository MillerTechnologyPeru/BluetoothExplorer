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
    
    static let store = Store()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                CentralList()
                Text("Scan for devices")
            }
            .environment(Self.store)
        }
    }
}
