//
//  AttributeValueCell.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import SwiftUI

struct AttributeValueCell: View {
    
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
        attributeValue.data.description
    }
}


