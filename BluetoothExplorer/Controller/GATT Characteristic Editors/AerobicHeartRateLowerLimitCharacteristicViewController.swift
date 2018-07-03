//
//  AerobicHeartRateLowerLimitCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 7/3/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import Foundation
import UIKit
import CoreData
import Bluetooth
import GATT

final class AerobicHeartRateLowerLimitCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - Properties
    
    private let cellIdentifier = R.nib.inputTextViewCell.name
    
    private var fields = [Field]()
    
    var value = GATTAerobicHeartRateLowerLimit(beats: 98)
    
    var valueDidChange: ((GATTAerobicHeartRateLowerLimit) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.lowerLimit("\(value.beats.rawValue)")]
        tableView.register(R.nib.inputTextViewCell(), forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
    }
    
    // MARK: - UITableViewController
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fields.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let field = fields[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! InputTextViewCell
        cell.selectionStyle = .none
        
        configure(cell, field: field)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! InputTextViewCell
        cell.inputTextView.textField.becomeFirstResponder()
    }
    
    // MARK: - Methods
    
    func configure(_ cell: InputTextViewCell, field: Field) {
        
        cell.inputTextView.value = field.bluetoothValue
        cell.inputTextView.isEnabled = valueDidChange != nil
        cell.inputTextView.keyboardType = field.keyboardType
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
        cell.inputTextView.validator = { value in
            
            guard value.trim() != ""
                else { return .none }
            
            switch field {
            case .lowerLimit:
                
                guard let _ = UInt8(value)
                    else { return .error("Maximum value is 0xFF") }
            }
            
            return .none
        }
    }
}

extension AerobicHeartRateLowerLimitCharacteristicViewController {
    
    enum Field {
        
        case lowerLimit(String)
        
        var title: String {
            
            switch self {
            case .lowerLimit: return "Lower Limit"
            }
        }
        
        var bluetoothValue: String {
            
            switch self {
            case .lowerLimit(let value): return value
            }
        }
        
        var keyboardType: UIKeyboardType { return .numberPad }
    }
}
