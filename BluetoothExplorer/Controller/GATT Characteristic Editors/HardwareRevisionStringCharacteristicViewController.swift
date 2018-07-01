//
//  HardwareRevisionStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/28/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class HardwareRevisionStringCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var hardwareTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTHardwareRevisionString = ""
    
    var valueDidChange: ((GATTHardwareRevisionString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = hardwareTextField.text
            else { return }
        
        value = GATTHardwareRevisionString(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        hardwareTextField.isEnabled = valueDidChange != nil
        hardwareTextField.text = value.rawValue
    }
}
