//
//  AttributeValueCell.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import Bluetooth
import SwiftUI

struct AttributeValueCell: View {
    
    let uuid: BluetoothUUID
    
    let attributeValue: AttributeValue
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            Text(verbatim: data)
            Text(type)
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(verbatim: date)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

extension AttributeValueCell {
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var date: String {
        Self.dateFormatter.string(from: attributeValue.date)
    }
    
    var type: LocalizedStringKey {
        switch attributeValue.type {
        case .read:
            return "Read"
        case .write:
            return "Write"
        case .notification:
            return "Notification"
        }
    }
    
    var data: String {
        uuid.description(for: attributeValue.data) ?? (attributeValue.data as NSData).description
    }
}

#if DEBUG
struct AttributeValueCell_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            AttributeValueCell(
                uuid: .deviceName,
                attributeValue: AttributeValue(
                    date: Date(),
                    type: .read,
                    data: Data("iPhone".utf8)
                )
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Read")
            
            AttributeValueCell(
                uuid: BluetoothUUID(),
                attributeValue: AttributeValue(
                    date: Date(),
                    type: .write,
                    data: Data("12345".utf8)
                )
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Write")
            
            AttributeValueCell(
                uuid: .batteryLevel,
                attributeValue:
                    AttributeValue(
                        date: Date(),
                        type: .notification,
                        data: Data([99])
                    )
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Notification")
        }
    }
}
#endif
