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
                        
                        NativeAppDelegate.shared.window?.rootViewController?.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        }
    }
}

protocol TableViewActivityIndicatorViewController: ActivityIndicatorViewController {
    
    var tableView: UITableView! { get }
    
    var refreshControl: UIRefreshControl? { get }
    
    #if os(iOS)
    var activityIndicator: UIActivityIndicatorView { get }
    #elseif os(Android) || os(macOS)
    var progressDialog: AndroidProgressDialog { get }
    #endif
}

extension TableViewActivityIndicatorViewController {
    
    func showActivity() {
        
        self.view.isUserInteractionEnabled = false
        
        if refreshControl?.isRefreshing ?? false {
            
            // refresh control animating
        } else {
            
            #if os(iOS)
            activityIndicator.startAnimating()
            #else
            progressDialog.show()
            #endif
        }
    }
    
    func hideActivity(animated: Bool = true) {
        
        self.view.isUserInteractionEnabled = true
        
        if refreshControl?.isRefreshing ?? false {
            
            refreshControl?.endRefreshing()
        } else {
            #if os(iOS)
            activityIndicator.stopAnimating()
            #else
            progressDialog.dismiss()
            #endif
            
        }
    }
}

internal extension ActivityIndicatorViewController {
    
    #if os(iOS)
    func loadActivityIndicatorView() -> UIActivityIndicatorView {
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.frame.origin = CGPoint(x: 6.5, y: 15)
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 33, height: 44))
        view.backgroundColor = .clear
        view.addSubview(activityIndicator)
        
        let barButtonItem = UIBarButtonItem(customView: view)
        self.navigationItem.rightBarButtonItem = barButtonItem
        return activityIndicator
    }
    #endif
}
