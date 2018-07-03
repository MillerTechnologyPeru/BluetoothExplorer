//
//  BatteryPowerStateCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 7/2/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

import UIKit
import Bluetooth

final class PnPIDCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    typealias VendorIDSource = GATTPnPID.VendorIDSource
    
    // MARK: - Properties
    
    private let cellIdentifier = "InputTextViewCell"
    
    private var fields = [Field]()
    
    var value = GATTPnPID(vendorIdSource: .fromAssignedNumbersDocument, vendorId: 0, productId: 0, productVersion: 0)
    
    var valueDidChange: ((GATTPnPID) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.vendorIdSource("\(value.vendorIdSource)"),
                  .vendorId("\(value.vendorId)"),
                  .productId("\(value.productId)"),
                  .productVersionId("\(value.productVersion)"),]
        
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
        cell.inputTextView.posibleInputValues = field.posibleValues
//        cell.inputTextView.isEnabled = valueDidChange != nil
        cell.inputTextView.keyboardType = field.keyboardType
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
        cell.inputTextView.validator = { value in
            
            guard value.trim() != ""
                else { return .none }
            
            switch field {
            case .vendorId(let value):
                
                guard let _ = UInt16(value)
                    else { return .error("Maximum value is 0xFFFF)") }
                
            case .productId(let value):
                
                guard let _ = UInt16(value)
                    else { return .error("Maximum value is 0xFFFF)") }
                
            case .productVersionId(let value):
                
                guard let _ = UInt16(value)
                    else { return .error("Maximum value is 0xFFFF)") }
                
            default:
                break
            }
            
            return .none
        }
    }
}

extension PnPIDCharacteristicViewController {
    
    enum Field {
        
        case vendorIdSource(String)
        case vendorId(String)
        case productId(String)
        case productVersionId(String)
        
        var title: String {
            
            switch self {
            case .vendorIdSource:
                return "Vendor ID Source"
                
            case .vendorId:
                return "Vendor ID"
                
            case .productId:
                return "Product ID"
                
            case .productVersionId:
                return "Product Version ID"
            }
        }
        
        var bluetoothValue: String {
            switch self {
            case .vendorIdSource(let value):
                return value
                
            case .vendorId(let value):
                return value
                
            case .productId(let value):
                return value
                
            case .productVersionId(let value):
                return value
            }
        }
        
        var posibleValues: [String] {
            switch self {
            case .vendorIdSource:
                return [VendorIDSource.fromAssignedNumbersDocument.rawValue.description,
                        VendorIDSource.fromVendorIDValue.rawValue.description]
                
            default:
                return []
            }
        }
        
        var keyboardType: UIKeyboardType {
            switch self {
            case .vendorIdSource:
                return .default
                
            default:
                return.numberPad
            }
        }
    }
}
