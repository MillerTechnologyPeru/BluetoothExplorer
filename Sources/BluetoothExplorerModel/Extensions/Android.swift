//
//  Android.swift
//  bluetooth-explorer
//
//  Created by Alsey Coleman Miller on 2/14/26.
//

#if os(Android)
import Foundation
import SwiftJava
import AndroidContent

public extension AndroidContent.Context {

    /// Get the Skip application's Android Context from ProcessInfo.
    static func androidContext() throws -> AndroidContent.Context? {
        try SkipProcessInfo.processInfo().getAndroidContext()
    }
}

@JavaClass("skip.foundation.ProcessInfo")
open class SkipProcessInfo: JavaObject {
    
    @JavaMethod
    @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
    
    class func processInfo() throws -> SkipProcessInfo {
        try JavaClass<SkipProcessInfo>().Companion.getProcessInfo()
    }
    
    @JavaMethod
    open func getAndroidContext() -> AndroidContent.Context?
    
    @JavaClass("skip.foundation.ProcessInfo$Companion")
    open class Companion: JavaObject {
        
        @JavaMethod
        func getProcessInfo() -> SkipProcessInfo!
    }
}

extension JavaClass<SkipProcessInfo> {
    
    @JavaStaticField(isFinal: true)
    public var Companion: SkipProcessInfo.Companion!
}

#endif
