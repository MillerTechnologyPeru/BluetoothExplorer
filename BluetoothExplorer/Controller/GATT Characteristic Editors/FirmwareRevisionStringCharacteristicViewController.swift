//
//  FirmwareRevisionStringCharacteristicsViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class FirmwareRevisionStringCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var firmwareTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTFirmwareRevisionString = ""
    
    var valueDidChange: ((GATTFirmwareRevisionString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = firmwareTextField.text
            else { return }
        
        value = GATTFirmwareRevisionString(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        firmwareTextField.isEnabled = valueDidChange != nil
        firmwareTextField.text = value.rawValue
    }
}
