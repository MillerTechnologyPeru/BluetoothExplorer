//
//  AttributeValuesSection.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import Bluetooth
import SwiftUI

struct AttributeValuesSection: View {
    
    let uuid: BluetoothUUID
    
    let values: [AttributeValue]
    
    var body: some View {
        Section(content: {
            ForEach(values) {
                AttributeValueCell(
                    uuid: uuid,
                    attributeValue: $0
                )
            }
        }, header: {
            Text("Values")
        })
    }
}
