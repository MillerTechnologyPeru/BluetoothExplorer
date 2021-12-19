//
//  ServicesList.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct ServicesList <Peripheral: Peer, ID: Hashable>: View {
    
    let services: [Service<Peripheral, ID>]
    
    var body: some View {
        List {
            ForEach(services) {
                Text($0.uuid.description)
            }
        }
    }
}
