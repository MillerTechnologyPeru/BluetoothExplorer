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

#if DEBUG
struct AttributeCell_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            AttributeCell(uuid: .deviceInformation)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .deviceInformation)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .deviceName)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .modelNumberString)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .serialNumberString)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .batteryLevel)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: .clientCharacteristicConfiguration)
                .previewLayout(.sizeThatFits)
        }
    }
}
#endif
