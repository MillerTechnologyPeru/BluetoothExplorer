//
//  FirmwareRevisionStringCharacteristicsViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class FirmwareRevisionStringCharacteristicViewController: UIViewController {
    
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

extension FirmwareRevisionStringCharacteristicViewController: CharacteristicViewController {
    
    static func fromStoryboard() -> FirmwareRevisionStringCharacteristicViewController {
        
        let storyboard = UIStoryboard(name: "FirmwareRevisionStringCharacteristic", bundle: .main)
        
        let viewController = storyboard.instantiateInitialViewController() as! FirmwareRevisionStringCharacteristicViewController
        
        return viewController
    }
}

