//
//  main.swift
//  AndroidUIKit
//
//  Created by Marco Estrella on 9/6/18.
//

import Foundation

#if os(iOS)

import UIKit

UIApplicationMain(0, nil, nil, NSStringFromClass(AppDelegate.self))

#else

import java_swift
import java_lang
import java_util
import Android
import AndroidUIKit

/// Needs to be implemented by app.
@_silgen_name("SwiftAndroidMainApplication")
public func SwiftAndroidMainApplication() -> SwiftApplication.Type {

    NSLog("\(#function)")

    return SwiftApplication.self
}

/// Needs to be implemented by app.
@_silgen_name("SwiftAndroidMainActivity")
public func SwiftAndroidMainActivity() -> SwiftSupportAppCompatActivity.Type {

    NSLog("\(#function)")

    return SwiftSupportAppCompatActivity.self
}

#endif