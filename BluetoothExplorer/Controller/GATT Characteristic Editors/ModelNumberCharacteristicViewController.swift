//
//  ModelNumberCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class ModelNumberCharacteristicViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var modelTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTModelNumber = ""
    
    var valueDidChange: ((GATTModelNumber) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = modelTextField.text
            else { return }
        
        value = GATTModelNumber(rawValue: text)
        valueDidChange?(value)
    }
}

// MARK: - CharacteristicViewController

extension ModelNumberCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> ModelNumberCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "ModelNumberCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! ModelNumberCharacteristicViewController
        
        return viewController
    }
}
