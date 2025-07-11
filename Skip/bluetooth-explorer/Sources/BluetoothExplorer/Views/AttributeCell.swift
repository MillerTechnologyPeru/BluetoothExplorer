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
            if let name = uuid.metadata?.name {
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
            AttributeCell(uuid: BluetoothUUID.Service.deviceInformation)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Service.deviceInformation)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Characteristic.deviceName)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Characteristic.modelNumberString)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Characteristic.serialNumberString)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Characteristic.batteryLevel)
                .previewLayout(.sizeThatFits)
            AttributeCell(uuid: BluetoothUUID.Descriptor.clientCharacteristicConfiguration)
                .previewLayout(.sizeThatFits)
        }
    }
}
#endif
