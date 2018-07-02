//
//  SystemIDViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/27/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class SystemIDCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    private let cellIdentifier = "InputTextViewCell"
    
    // MARK: - Properties
    
    private var fields = [Field]()
    
    var value = GATTSystemID(manufacturerIdentifier: 0, organizationallyUniqueIdentifier: 0)
    
    var valueDidChange: ((GATTSystemID) -> ())?
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.manufacturerIdentifier("\(value.manufacturerIdentifier)"),
                  .organizationIdentifier("\(value.organizationallyUniqueIdentifier)")]
        
        tableView.register(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)
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
        cell.inputTextView.keyboardType = .numberPad
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
        cell.inputTextView.validator = { value in
            
            guard value.trim() != ""
                else { return .none }
            
            switch field {
            case .manufacturerIdentifier:
                
                // TODO: Use Bluetooth max value
                guard let manufacturerIdValue = UInt64(value), manufacturerIdValue <= 1099511627775
                    else { return .error("Maximum value is \(1099511627775)") }
                
            case .organizationIdentifier:
        
                // TODO: Use Bluetooth max value
                guard let organizationIdvalue = UInt32(value), organizationIdvalue <= 16777215
                    else { return .error("Maximum value is \(16777215)") }
            }
            
            return .none
        }
    }
}

extension SystemIDCharacteristicViewController {
    
    enum Field {
        
        case manufacturerIdentifier(String)
        case organizationIdentifier(String)
        
        var title: String {
            
            switch self {
            case .manufacturerIdentifier:
                return "Manufacturer Identifier"
                
            case .organizationIdentifier:
                return "Organization Identifier"
            }
        }
        
        var bluetoothValue: String {
            switch self {
            case .manufacturerIdentifier(let value):
                return value
                
            case .organizationIdentifier(let value):
                return value
            }
        }
    }
}
