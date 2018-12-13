//
//  main.swift
//  AndroidUIKit
//
//  Created by Marco Estrella on 9/6/18.
//

#if os(Android) || os(macOS)

import Foundation
import Android
import AndroidUIKit

/// Needs to be implemented by app.
@_silgen_name("SwiftAndroidMainApplication")
public func SwiftAndroidMainApplication() -> SwiftApplication.Type {
    
    NSLog("\(#function)")
    
    // initialize singleton App Delegate
    UIApplication.shared.delegate = AndroidAppDelegate()
    
    // return specialized Android Application
    return AndroidUIKitApplication.self
}

/// Needs to be implemented by app.
@_silgen_name("SwiftAndroidMainActivity")
public func SwiftAndroidMainActivity() -> SwiftSupportAppCompatActivity.Type {
    
    NSLog("\(#function)")
    
    // return specialized Android Activity
    return AndroidUIKitMainActivity.self
}

#endif
