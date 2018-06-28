//
//  SerialNumberStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/28/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class SerialNumberStringCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var serialNumberTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTSerialNumberString = ""
    
    var valueDidChange: ((GATTSerialNumberString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = serialNumberTextField.text
            else { return }
        
        value = GATTSerialNumberString(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        serialNumberTextField.isEnabled = valueDidChange != nil
        serialNumberTextField.text = value.rawValue
    }
}
