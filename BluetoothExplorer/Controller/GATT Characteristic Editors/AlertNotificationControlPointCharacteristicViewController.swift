//
//  AlertNotificationControlPointCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 7/3/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit
import Bluetooth

final class AlertNotificationControlPointCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    typealias Command = GATTAlertNotificationControlPoint.Command
    
    // MARK: - Properties
    
    private let cellIdentifier = R.nib.inputTextViewCell.name
    
    private var fields = [Field]()
    
    var value = GATTAlertNotificationControlPoint(command: .enableNewIncomingAlertNotification, category: .simpleAlert)
    
    var valueDidChange: ((GATTAlertNotificationControlPoint) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.command("\(value.command.rawValue)"),
                  .alertCategory("\(value.category.rawValue)")]
        
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
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
    }
}

extension AlertNotificationControlPointCharacteristicViewController {
    
    enum Field {
        
        case command(String)
        case alertCategory(String)
        
        var title: String {
            
            switch self {
            case .command:
                return "Command"
                
            case .alertCategory:
                return "Alert Category"
            }
        }
        
        var bluetoothValue: String {
            switch self {
            case .command(let value):
                return value
                
            case .alertCategory(let value):
                return value
            }
        }
        
        var posibleValues: [String] {
            switch self {
            case .command:
                return [Command.enableNewIncomingAlertNotification.rawValue.description,
                        Command.enableUnreadCategoryStatusNotification.rawValue.description,
                        Command.disableNewIncomingAlertNotification.rawValue.description,
                        Command.disableUnreadCategoryStatusNotification.rawValue.description,
                        Command.notifyNewIncomingAlertImmediately.rawValue.description,
                        Command.notifyUnreadCategoryStatusImmediately.rawValue.description]
                
            case .alertCategory:
                return [GATTAlertCategory.simpleAlert.rawValue.description,
                        GATTAlertCategory.email.rawValue.description,
                        GATTAlertCategory.news.rawValue.description,
                        GATTAlertCategory.call.rawValue.description,
                        GATTAlertCategory.missedCall.rawValue.description,
                        GATTAlertCategory.sms.rawValue.description,
                        GATTAlertCategory.voiceMail.rawValue.description,
                        GATTAlertCategory.schedule.rawValue.description,
                        GATTAlertCategory.highPrioritizedAlert.rawValue.description,
                        GATTAlertCategory.instantMessage.rawValue.description]
            }
        }
    }
}
