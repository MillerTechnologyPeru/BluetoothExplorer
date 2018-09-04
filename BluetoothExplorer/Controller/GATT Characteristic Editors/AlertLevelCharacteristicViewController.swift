//
//  AlertLevelCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 7/2/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Bluetooth
import GATT

final class AlertLevelCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - Properties
    
    private let cellIdentifier = R.nib.inputTextViewCell.name
    
    private var fields = [Field]()
    
    var value: GATTAlertLevel = .none
    
    var valueDidChange: ((GATTAlertLevel) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.level("\(value.rawValue)")]
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
        cell.inputTextView.posibleInputValues = field.posibleValues
        cell.inputTextView.isEnabled = valueDidChange != nil
        cell.inputTextView.keyboardType = field.keyboardType
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
    }
}

extension AlertLevelCharacteristicViewController {
    
    enum Field {
        
        case level(String)
        
        var title: String {
            
            switch self {
            case .level: return "Level"
            }
        }
        
        var bluetoothValue: String {
            
            switch self {
            case .level(let value): return value
            }
        }
        
        var posibleValues: [String] {
            
            switch self {
            case .level:
                return [GATTAlertLevel.none.rawValue.description,
                        GATTAlertLevel.mild.rawValue.description,
                        GATTAlertLevel.high.rawValue.description]
            }
        }
        
        var keyboardType: UIKeyboardType { return .default }
    }
}
