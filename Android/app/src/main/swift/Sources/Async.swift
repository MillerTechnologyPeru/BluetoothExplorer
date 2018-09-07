//
//  Async.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/19/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import Dispatch

func mainQueue(_ block: @escaping () -> ()) {
    
    DispatchQueue.main.async(execute: block)
}

/// Perform a task on the internal queue.
func async(_ block: @escaping () -> ()) {
    
    appQueue.async(execute: block)
}

let appQueue = DispatchQueue(label: "App Queue")
