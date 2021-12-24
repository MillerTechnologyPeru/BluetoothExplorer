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
            data
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
    
    static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
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
    
    var data: some View {
        // empty data
        guard attributeValue.data.isEmpty == false else {
            return AnyView(Text("Empty data"))
        }
        if let description = uuid.description(for: attributeValue.data) {
            return AnyView(Text(verbatim: description))
        } else {
            return AnyView(
                VStack(alignment: .leading, spacing: nil) {
                    Text(verbatim: "0x" + attributeValue.data.toHexadecimal())
                    Text(verbatim: Self.byteCountFormatter.string(fromByteCount: numericCast(attributeValue.data.count)))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            )
        }
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
