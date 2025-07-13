//
//  UnitEmitter.swift
//  BluetoothExplorerApp
//
//  Created by Alsey Coleman Miller on 7/13/25.
//

import JavaKit

/// Bridge from Swift to Kotlin Coroutines
@JavaClass("com.pureswift.swiftandroid.UnitEmitter")
open class UnitEmitter: JavaObject {
    
    @JavaMethod
    @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
    
    @JavaMethod
    func emit()
}
