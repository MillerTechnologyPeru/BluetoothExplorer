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

public struct AttributeValue: Equatable, Hashable, Identifiable {

    /// Stable unique identifier. Notifications can arrive in bursts within the same millisecond,
    /// so the timestamp is not a safe identity — this is used to key decoded results.
    public let id: UUID

    public let date: Date

    public let type: AttributeValueType

    public let data: Data

    public init(
        id: UUID = UUID(),
        date: Date,
        type: AttributeValueType,
        data: Data
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.data = data
    }
}
