//
//  AttributeCell.swift
//  
//
//  Created by Alsey Coleman Miller on 19/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct AttributeCell: View {
    
    let uuid: BluetoothUUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            Text(uuid.rawValue)
            if let name = uuid.name {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
