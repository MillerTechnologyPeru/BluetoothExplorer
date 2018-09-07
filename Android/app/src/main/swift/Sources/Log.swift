//
//  Log.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 9/7/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

/// app logger function
func log(_ message: String) {

    #if os(Android)
    NSLog(message)
    #else
    print(message)
    #endif
}
