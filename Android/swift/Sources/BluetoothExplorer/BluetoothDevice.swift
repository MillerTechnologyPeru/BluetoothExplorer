//
//  BluetoothDevice.swift
//  
//
//  Created by Alsey Coleman Miller on 11/30/22.
//

import Foundation

struct BluetoothDevice: Equatable, Hashable, Codable {
    
    let id: String
    
    let date: Foundation.Date
    
    let address: String
    
    let name: String?
    
    let company: String?
}
