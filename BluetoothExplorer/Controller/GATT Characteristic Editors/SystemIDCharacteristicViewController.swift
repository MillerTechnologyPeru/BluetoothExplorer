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
    
    @IBOutlet weak var menufacturerIdentifierInputText: InputTextView!
    
    @IBOutlet weak var organizationIdentifierInputText: InputTextView!
    
    // MARK: - Properties
    
    var value = GATTSystemID(manufacturerIdentifier: 0, organizationallyUniqueIdentifier: 0)!
    
    var valueDidChange: ((GATTSystemID) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
        
        menufacturerIdentifierInputText.validator = { value in
            
            guard value.trim() != ""
                else { return .none }
            
            // TODO: Use Bluetooth max value
            guard let manufacturerIdValue = UInt64(value), manufacturerIdValue <= 1099511627775
                else { return .error("Maximum value is \(1099511627775)") }
            
            return .none
        }
        
        organizationIdentifierInputText.validator = { value in
            
            guard value.trim() != ""
                else { return .none }
            
            // TODO: Use Bluetooth max value
            guard let organizationIdvalue = UInt32(value), organizationIdvalue <= 16777215
                else { return .error("Maximum value is \(16777215)") }
            
            return .none
        }
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
        
        menufacturerIdentifierInputText.keyboardType = .numberPad
        organizationIdentifierInputText.keyboardType = .numberPad
    }
    
    private func updateText() {
        
        menufacturerIdentifierInputText.isEnabled = valueDidChange != nil
        organizationIdentifierInputText.isEnabled = valueDidChange != nil

        menufacturerIdentifierInputText.value = "\(value.manufacturerIdentifier)"
        organizationIdentifierInputText.value = "\(value.organizationallyUniqueIdentifier)"
    }
}
