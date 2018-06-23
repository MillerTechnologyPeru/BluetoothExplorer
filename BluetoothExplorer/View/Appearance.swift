//
//  Appearance.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/22/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit

internal func ConfigureAppearance() {
    
    UINavigationBar.appearance().tintColor = .white
    
    if #available(iOS 11.0, *) {
        UINavigationBar.appearance().prefersLargeTitles = true
        UINavigationBar.appearance().barTintColor = UIColor(named: "NavigationBarTintColor")!
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]
    } else {
        UINavigationBar.appearance().barTintColor = .blue
    }
}
