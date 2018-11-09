//
//  ActivityIndicatorViewController.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/19/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

protocol ActivityIndicatorViewController: class {
    
    var view: UIView! { get }
    
    var navigationItem: UINavigationItem { get }
    
    var navigationController: UINavigationController? { get }
    
    func showActivity()
    
    func hideActivity(animated: Bool)
}

extension ActivityIndicatorViewController {
    
    func performActivity <T> (showActivity: Bool = true,
                              _ asyncOperation: @escaping () throws -> T,
                              completion: ((Self, T) -> ())? = nil) {
        
        if showActivity { self.showActivity() }
        
        async {
            
            do {
                
                let value = try asyncOperation()
                
                mainQueue { [weak self] in
                    
                    guard let controller = self
                        else { return }
                    
                    if showActivity { controller.hideActivity(animated: true) }
                    
                    // success
                    completion?(controller, value)
                }
            }
                
            catch {
                
                mainQueue { [weak self] in
                    
                    guard let controller = self as? (UIViewController & ActivityIndicatorViewController)
                        else { return }
                    
                    if showActivity { controller.hideActivity(animated: false) }
                    
                    // show error
                    
                    log("⚠️ Error: \(error)")
                    
                    if (controller as UIViewController).view.window != nil {
                        
                        controller.showErrorAlert(error.localizedDescription)
                        
                    } else {
                        
                        AppDelegate.shared.window?.rootViewController?.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
}
