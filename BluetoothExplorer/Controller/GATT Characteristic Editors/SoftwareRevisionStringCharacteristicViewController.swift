//
//  SoftwareRevisionStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class SoftwareRevisionStringCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var softwareTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTSoftwareRevisionString = ""
    
    var valueDidChange: ((GATTSoftwareRevisionString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = softwareTextField.text
            else { return }
        
        value = GATTSoftwareRevisionString(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        softwareTextField.isEnabled = valueDidChange != nil
        softwareTextField.text = value.rawValue
    }
}
