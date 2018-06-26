//
//  ManufacturerNameStringCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class ManufacturerNameStringCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var manufacturerNameTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTManufacturerNameString = ""
    
    var valueDidChange: ((GATTManufacturerNameString) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let text = manufacturerNameTextField.text
            else { return }
        
        value = GATTManufacturerNameString(rawValue: text)
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    func updateText() {
        
        manufacturerNameTextField.text = value.rawValue
    }
}
