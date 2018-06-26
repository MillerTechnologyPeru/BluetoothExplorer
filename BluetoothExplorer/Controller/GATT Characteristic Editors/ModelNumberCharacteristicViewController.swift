//
//  ModelNumberCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class ModelNumberCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var modelTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTModelNumber = ""
    
    var valueDidChange: ((GATTModelNumber) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: UITextField) {
        
        guard let text = modelTextField.text
            else { return }
        
        value = GATTModelNumber(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        modelTextField.isEnabled = valueDidChange != nil
        modelTextField.text = value.rawValue
    }
}
