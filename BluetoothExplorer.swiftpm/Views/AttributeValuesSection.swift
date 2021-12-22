//
//  AttributeValuesSection.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation
import SwiftUI

struct AttributeValuesSection: View {
    
    let values: [AttributeValue]
    
    var body: some View {
        Section(content: {
            ForEach(values) {
                AttributeValueCell(attributeValue: $0)
            }
        }, header: {
            Text("Values")
        })
    }
}
