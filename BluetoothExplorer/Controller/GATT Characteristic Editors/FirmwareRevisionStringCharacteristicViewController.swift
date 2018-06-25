//
//  FirmwareRevisionStringCharacteristicsViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class FirmareRevisionStringCharacteristicViewController: UIViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var firmwareTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTFirmwareRevisionString = ""
    
    var valueDidChange: ((GATTFirmwareRevisionString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = firmwareTextField.text
            else { return }
        
        value = GATTFirmwareRevisionString(rawValue: text)
        valueDidChange?(value)
    }
}

// MARK: - CharacteristicViewController

extension FirmareRevisionStringCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> FirmareRevisionStringCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "FirmareRevisionStringCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! FirmareRevisionStringCharacteristicViewController
        
        return viewController
    }
}

