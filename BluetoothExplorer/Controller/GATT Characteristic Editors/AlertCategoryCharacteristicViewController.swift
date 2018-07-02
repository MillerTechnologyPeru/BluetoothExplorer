//
//  AlertCategoryCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/28/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class AlertCategoryCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var alertCategoryTextField: InputTextField!
    
    var value: GATTAlertCategory = .simpleAlert
    
    var valueDidChange: ((GATTAlertCategory) -> ())?
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let values: [GATTAlertCategory] = [.simpleAlert, .email, .news, .call, .missedCall, .sms, .voiceMail,
                                           .schedule, .highPrioritizedAlert, .instantMessage]
        
        let haxedecimals: [String] = values.sorted(by: { $1.rawValue > $0.rawValue }).map { "\($0.name) - 0x\($0.rawValue.toHexadecimal())" }
        
        alertCategoryTextField.posibleValues = haxedecimals
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        alertCategoryTextField.isEnabled = valueDidChange != nil
        alertCategoryTextField.text = "0x\(value.rawValue.toHexadecimal())"
    }
}
