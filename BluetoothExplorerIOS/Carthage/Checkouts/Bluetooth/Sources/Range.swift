//
//  Range.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 3/31/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if swift(>=4.0)
public typealias Integer = BinaryInteger
#endif

internal extension Range where Bound: Integer {
    
    func isSubset(_ other: Range) -> Bool {
        
        return self.lowerBound >= other.lowerBound
            && self.lowerBound <= other.upperBound
            && self.upperBound >= other.lowerBound
            && self.upperBound <= other.upperBound
    }
}
