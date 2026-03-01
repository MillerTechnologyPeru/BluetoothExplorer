//
//  Cache.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

internal struct Cache<T> {
    
    let capacity: Int
    
    private(set) var values: [T]
    
    init(capacity: Int) {
        assert(capacity > 0)
        self.capacity = capacity
        self.values = [T]()
        self.values.reserveCapacity(capacity)
    }
    
    mutating func append(_ value: T) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst()
        }
    }
    
    mutating func removeAll() {
        values.removeAll(keepingCapacity: true)
    }
}
