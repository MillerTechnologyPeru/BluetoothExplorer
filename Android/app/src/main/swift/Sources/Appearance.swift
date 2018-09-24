//
//  Appearance.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 9/23/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

/// Configure the application's UI appearance
func configureAppearance() {
    
    #if os(iOS)
    
    if #available(iOS 11.0, *) {
        UINavigationBar.appearance().prefersLargeTitles = true
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
    }
    
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
    UINavigationBar.appearance().barTintColor = UIColor(red: 0.386, green: 0.707, blue: 1.0, alpha: 1.0)
    
    #endif
}
