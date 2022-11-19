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
            }
            .onAppear {
                NativeCentral.shared.log = { print("Central: \($0)") }
            }
        }
    }
}
