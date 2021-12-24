//
//  Hexadecimal.swift
//  Bluetooth
//
//  Created by Alsey Coleman Miller on 3/2/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation

internal extension FixedWidthInteger {
    
    func toHexadecimal() -> String {
        
        var string = String(self, radix: 16)
        while string.utf8.count < (MemoryLayout<Self>.size * 2) {
            string = "0" + string
        }
        assert(string.utf8.count == MemoryLayout<Self>.size * 2)
        return string.uppercased()
    }
    
    init?<T: StringProtocol>(hexadecimal string: T) {
        self.init(string, radix: 16)
    }
}

internal extension Collection where Element: FixedWidthInteger {
    
    func toHexadecimal() -> String {
        let length = count * MemoryLayout<Element>.size * 2
        var string = ""
        string.reserveCapacity(length)
        string = reduce(into: string) { $0 += $1.toHexadecimal() }
        assert(string.count == length)
        return string
    }
}

internal extension Data {
    
    init?(hexadecimal string: String) {
        let elementStringSize = MemoryLayout<Element>.size * 2 // 2 for UInt8
        guard string.isEmpty == false else {
            self.init()
            return
        }
        guard string.count % elementStringSize == 0 else {
            return nil
        }
        let elementsCount = string.count / elementStringSize
        let elements = (0 ..< elementsCount)
            .lazy
            .map { ($0 * elementStringSize, ($0+1) * elementStringSize) }
            .map { string.index(string.startIndex, offsetBy: $0.0) ..< string.index(string.startIndex, offsetBy: $0.1) }
            .map { string[$0] }
        self.init()
        self.reserveCapacity(elementsCount)
        for substring in elements {
            guard let element = Element.init(hexadecimal: substring) else {
                return nil
            }
            self.append(element)
        }
        assert(self.count == elementsCount)
    }
}
