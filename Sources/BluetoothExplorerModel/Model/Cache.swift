//
//  Cache.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

public struct Cache<T> {
    
    public let capacity: Int
    
    public private(set) var values: [T]
    
    public init(capacity: Int) {
        assert(capacity > 0)
        self.capacity = capacity
        self.values = [T]()
        self.values.reserveCapacity(capacity)
    }
    
    public mutating func append(_ value: T) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst()
        }
    }
    
    public mutating func removeAll() {
        values.removeAll(keepingCapacity: true)
    }
}
