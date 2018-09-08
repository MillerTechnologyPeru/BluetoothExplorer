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
    
    #if os(Android) || os(macOS)
    var bluetoothEnabled: (() -> ())?
    #endif
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        NSLog("\(#function)")
        
        #if os(Android) || os(macOS)
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
        
        // request Bluetooth permissions
        #if os(Android) || os(macOS)
        self.enableBluetooth()
        #endif
        
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
}

extension AppDelegate {
    
    func application(_ application: UIApplication, activityResult requestCode: Int, resultCode: Int, data: Android.Content.Intent?) {
        
        NSLog("\(type(of: self)) \(#function) - requestCode = \(requestCode) - resultCode = \(resultCode)")
        
        if resultCode == AndroidPermissionRequest.enableBluetooth,
           resultCode == SwiftSupportAppCompatActivity.RESULT_OK {
            
            // no need to request permissions
            if requestLocationPermissions() {
                
                //
                bluetoothEnabled?()
            }
        }
    }
    
    func application(_ application: UIApplication, requestPermissionsResult requestCode: Int, permissions: [String], grantResults: [Int]) {
        
        NSLog("\(type(of: self)) \(#function)")
        
        if requestCode == AndroidPermissionRequest.gps {
            
            if grantResults[0] == Android.Content.PM.PackageManager.Permission.granted.rawValue {
                
                // permission granted, now we can scan
                bluetoothEnabled?()
                
            } else {
                
                NSLog(" \(type(of: self)) \(#function) GPS Permission is required")
            }
        }
    }
}

extension AppDelegate {
    
    /// Checks if permissions are needed.
    @discardableResult
    func enableBluetooth(hostController: Android.Bluetooth.Adapter = Android.Bluetooth.Adapter.default!) -> Bool {
        
        guard hostController.isEnabled() == false
            else { return requestLocationPermissions() }
        
        let enableBluetoothIntent = Android.Content.Intent(action: Android.Bluetooth.Adapter.Action.requestEnable.rawValue)
        
        UIApplication.shared.androidActivity.startActivityForResult(intent: enableBluetoothIntent,
                                                                    requestCode: AndroidPermissionRequest.enableBluetooth)
        
        log("\(type(of: self)) \(#function) enable Bluetooth")
        
        return false
    }
    
    @discardableResult
    func requestLocationPermissions() -> Bool {
        
        let activity = UIApplication.shared.androidActivity
        
        if Android.OS.Build.Version.Sdk.sdkInt.rawValue >= Android.OS.Build.VersionCodes.M,
            activity.checkSelfPermission(permission: Android.ManifestPermission.accessCoarseLocation.rawValue) != Android.Content.PM.PackageManager.Permission.granted.rawValue {
            
            log("\(type(of: self)) \(#function) request permission")
            
            let permissions = [Android.ManifestPermission.accessCoarseLocation.rawValue]
            
            activity.requestPermissions(permissions: permissions, requestCode: AndroidPermissionRequest.gps)
            
            return false
            
        } else {
            
            log("\(type(of: self)) \(#function) dont request permission")
            
            return true
        }
    }
}

#endif
