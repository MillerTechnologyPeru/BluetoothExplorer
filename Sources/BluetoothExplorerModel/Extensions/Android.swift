//
//  Android.swift
//  bluetooth-explorer
//
//  Created by Alsey Coleman Miller on 2/14/26.
//

#if os(Android)
import Foundation
import JavaKit
import AndroidContent

public extension AndroidContent.Context {

    /// Get the application's Android Context from ProcessInfo.
    static func androidContext() -> AndroidContent.Context {
        guard let javaObject = ProcessInfo.processInfo.dynamicAndroidContext().toJavaObject(options: .kotlincompat) else {
            fatalError("Unable to get Android context")
        }
        let environment = try! JavaVirtualMachine.shared().environment()
        return AndroidContent.Context(javaThis: javaObject, environment: environment)
    }
}
#endif
