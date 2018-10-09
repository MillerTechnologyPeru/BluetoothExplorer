//
//  Async.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/19/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import Dispatch

#if os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

func mainQueue(_ block: @escaping () -> ()) {
    
    #if os(iOS)
    DispatchQueue.main.async(execute: block)
    #elseif os(Android) || os(macOS)
    UIApplication.shared.androidActivity.runOnMainThread(block)
    #endif
}

/// Perform a task on the internal queue.
func async(_ block: @escaping () -> ()) {
    
    appQueue.async(execute: block)
}

let appQueue = DispatchQueue(label: "App Queue")
