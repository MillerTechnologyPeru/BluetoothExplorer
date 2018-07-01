//
//  Integer.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/28/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

internal extension UInt8 {
    
    func toHexadecimal() -> String {
        
        var string = String(self, radix: 16)
        
        if string.utf8.count == 1 {
            
            string = "0" + string
        }
        
        return string.uppercased()
    }
}
