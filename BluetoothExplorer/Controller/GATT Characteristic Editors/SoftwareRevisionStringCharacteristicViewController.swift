//
//  SoftwareRevisionStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class SoftwareRevisionStringCharacteristicViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var softwareTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTSoftwareRevisionString = ""
    
    var valueDidChange: ((GATTSoftwareRevisionString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = softwareTextField.text
            else { return }
        
        value = GATTSoftwareRevisionString(rawValue: text)
        valueDidChange?(value)
    }
}

// MARK: - CharacteristicViewController

extension SoftwareRevisionStringCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> SoftwareRevisionStringCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "SoftwareRevisionStringCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! SoftwareRevisionStringCharacteristicViewController
        
        return viewController
    }
}
