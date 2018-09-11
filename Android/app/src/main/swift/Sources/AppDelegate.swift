//
//  AppDelegate.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 9/7/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

import Bluetooth
import GATT

final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var shared: AppDelegate { return UIApplication.shared.delegate as! AppDelegate }
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        NSLog("\(#function)")
        
        #if os(Android)
        NSLog("UIScreen scale: \(UIScreen.main.scale)")
        NSLog("UIScreen native scale: \(UIScreen.main.nativeScale)")
        NSLog("UIScreen size: \(UIScreen.main.bounds.size)")
        NSLog("UIScreen native size: \(UIScreen.main.nativeBounds.size)")
        #endif
        
        // initalize BLE
        NativeCentral.shared.log = { log("Central: \($0)") }
        
        // load window and view controller
        
        let viewController = CentralViewController()
        
        let navigationController = UINavigationController(rootViewController: viewController)
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = navigationController
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        NSLog("\(#function)")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        NSLog("\(#function)")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        NSLog("\(#function)")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        NSLog("\(#function)")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        NSLog("\(#function)")
    }
}

// MARK: - Android Permissions

#if os(Android) || os(macOS)

extension AppDelegate {
    
    internal struct AndroidPermissionRequest {
        
        static let enableBluetooth = 1000
        static let gps = 2000
    }
    
    /// Checks if permissions are needed.
    func requestBluetoothPermissions() -> Bool {
        
        let context = AndroidContextWrapper(casting: UIApplication.shared.androidActivity)!
        
        if Android.OS.Build.Version.Sdk.sdkInt.rawValue >= Android.OS.Build.VersionCodes.M,
            context.checkSelfPermission(permission: Android.ManifestPermission.accessCoarseLocation.rawValue) != Android.Content.PM.PackageManager.Permission.granted.rawValue {
            
            log("\(type(of: self)) \(#function) request permission")
            
            let permissions = [Android.ManifestPermission.accessCoarseLocation.rawValue]
            
            context.requestPermissions(permissions: permissions, requestCode: AndroidPermissionRequest.gps)
            
            return false
            
        } else {
            
            log("\(type(of: self)) \(#function) dont request permission")
            
            return true
        }
    }
}

#endif
