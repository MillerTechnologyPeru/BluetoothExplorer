//
//  InstantiableViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/26/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit

protocol InstantiableViewController {
    
    static func instantiate<T>() -> T
}

extension InstantiableViewController where Self: UIViewController {
    
    static func instantiate<T>() -> T {
        guard let storyboardName = String(describing: self).text(before: "ViewController") else {
            fatalError("The controller name is not standard.")
        }
        
        let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle(for: self))
        let identifier = String(describing: T.self)
        guard let viewController = storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
            fatalError("The storyboard identifier does not exist.")
        }
        
        return viewController
    }
    
}
