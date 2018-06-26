//
//  SystemIDCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/25/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class SystemIDCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var manufacturerIdentifierTextField: UITextField!
    
    @IBOutlet private(set) var organizationallyUniqueIdentifierTextField: UITextField!
    
    // MARK: - Properties
    
    var value: GATTSystemID = GATTSystemID(manufacturerIdentifier: 0, organizationallyUniqueIdentifier: 0)!
    
    var valueDidChange: ((GATTSystemID) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Actions
    
    @IBAction func textFieldEditingChanged(_ sender: Any) {
        
        guard let manufacturerIdentifierText = manufacturerIdentifierTextField.text
            else { return }
        
        guard let organizationallyUniqueIdentifierText = organizationallyUniqueIdentifierTextField.text
            else { return }
        
        guard let manufacturerIdentifier = UInt64(manufacturerIdentifierText)
            else { return }
        
        guard let organizationallyUniqueIdentifier = UInt32(organizationallyUniqueIdentifierText)
            else { return }
        
        guard let systemID = GATTSystemID(manufacturerIdentifier: manufacturerIdentifier,
                                          organizationallyUniqueIdentifier: organizationallyUniqueIdentifier)
            else { return }
        
        value = systemID
        valueDidChange?(value)
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        manufacturerIdentifierTextField.isEnabled = valueDidChange != nil
        organizationallyUniqueIdentifierTextField.isEnabled = valueDidChange != nil
        
        manufacturerIdentifierTextField.text = "\(value.manufacturerIdentifier)"
        organizationallyUniqueIdentifierTextField.text = "\(value.organizationallyUniqueIdentifier)"
    }
}
