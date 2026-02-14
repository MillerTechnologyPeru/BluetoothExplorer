//
//  AttributeValue.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import Foundation

public enum AttributeValueType: Equatable, Hashable {
    
    case read
    case write
    case notification
}

public struct AttributeValue: Equatable, Hashable {
    
    public let date: Date
    
    public let type: AttributeValueType
    
    public let data: Data
    
    public init(
        date: Date,
        type: AttributeValueType,
        data: Data
    ) {
        self.date = date
        self.type = type
        self.data = data
    }
}

extension AttributeValue: Identifiable {
    
    public var id: Date {
        date
    }
}
