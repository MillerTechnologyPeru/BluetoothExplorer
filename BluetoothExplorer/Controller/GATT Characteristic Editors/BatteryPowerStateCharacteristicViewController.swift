//
//  PnPIDCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/26/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class BatteryPowerStateCharacteristicViewController: UITableViewController, CharacteristicViewController, InstantiableViewController {
    
    typealias BatteryPresentState = GATTBatteryPowerState.BatteryPresentState
    typealias BatteryDischargeState = GATTBatteryPowerState.BatteryDischargeState
    typealias BatteryChargeState = GATTBatteryPowerState.BatteryChargeState
    typealias BatteryLevelState = GATTBatteryPowerState.BatteryLevelState
    
    // MARK: - Properties
    
    private let cellIdentifier = "InputTextViewCell"
    
    private var fields = [Field]()
    
    var value = GATTBatteryPowerState(presentState: .unknown, dischargeState: .unknown, chargeState: .unknown, levelState: .unknown)
    
    var valueDidChange: ((GATTBatteryPowerState) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fields = [.present("\(value.presentState.rawValue)"),
                  .discharge("\(value.dischargeState.rawValue)"),
                  .charge("\(value.chargeState.rawValue)"),
                  .level("\(value.levelState.rawValue)")]
        
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
        cell.inputTextView.isEnabled = valueDidChange != nil
        cell.inputTextView.keyboardType = field.keyboardType
        cell.inputTextView.fieldLabelText = field.title
        cell.inputTextView.placeholder = field.title
    }
}

extension BatteryPowerStateCharacteristicViewController {
    
    enum Field {
        
        case present(String)
        case discharge(String)
        case charge(String)
        case level(String)
        
        var title: String {
            
            switch self {
            case .present: return "Present State"
            case .discharge: return "Discharge State"
            case .charge: return "Charge State"
            case .level: return "Level State"
            }
        }
        
        var bluetoothValue: String {
            
            switch self {
            case .present(let value): return value
            case .discharge(let value): return value
            case .charge(let value): return value
            case .level(let value): return value
            }
        }
        
        var posibleValues: [String] {
            switch self {
            case .present:
                return [BatteryPresentState.unknown.rawValue.description,
                        BatteryPresentState.notSupported.rawValue.description,
                        BatteryPresentState.notPresent.rawValue.description,
                        BatteryPresentState.present.rawValue.description]
                
            case .discharge:
                return [BatteryDischargeState.unknown.rawValue.description,
                        BatteryDischargeState.notSupported.rawValue.description,
                        BatteryDischargeState.notDischarging.rawValue.description,
                        BatteryDischargeState.discharging.rawValue.description]
                
            case .charge:
                return [BatteryChargeState.unknown.rawValue.description,
                        BatteryChargeState.notChargeable.rawValue.description,
                        BatteryChargeState.notCharging.rawValue.description,
                        BatteryChargeState.charging.rawValue.description]
                
            case .level:
                return [BatteryLevelState.unknown.rawValue.description,
                        BatteryLevelState.notSupported.rawValue.description,
                        BatteryLevelState.good.rawValue.description,
                        BatteryLevelState.criticallyLow.rawValue.description]
            }
        }
        
        var keyboardType: UIKeyboardType { return .default }
    }
}
