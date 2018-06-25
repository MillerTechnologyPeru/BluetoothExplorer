//
//  ManufacturerNameStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class ManufacturerNameStringCharacteristicViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var manufacturerNameTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTManufacturerNameString = ""
    
    var valueDidChange: ((GATTManufacturerNameString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = manufacturerNameTextField.text
            else { return }
        
        value = GATTManufacturerNameString(rawValue: text)
        valueDidChange?(value)
    }
}

// MARK: - CharacteristicViewController

extension ManufacturerNameStringCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> ManufacturerNameStringCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "ManufacturerNameStringCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! ManufacturerNameStringCharacteristicViewController
        
        return viewController
    }
}
