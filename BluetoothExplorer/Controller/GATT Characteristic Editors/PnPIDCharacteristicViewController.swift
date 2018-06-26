//
//  PnPIDCharacteristicViewController.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/26/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit
import Bluetooth

final class PnPIDCharacteristicViewController: UIViewController, CharacteristicViewController, InstantiableViewController {
    
    typealias VendorIDSource = GATTPnPID.VendorIDSource
    
    // MARK: - IB Outlets
    
    @IBOutlet weak var vendorIDSourceTextField: UITextField!
    @IBOutlet weak var vendorIDTextField: UITextField!
    @IBOutlet weak var productIDTextField: UITextField!
    @IBOutlet weak var productVersionTextField: UITextField!
    
    // MARK: - Properties
    
    var value = GATTPnPID(vendorIdSource: VendorIDSource(rawValue: 0x01)!, vendorId: 0, productId: 0, productVersion: 0)
    
    var valueDidChange: ((GATTPnPID) -> ())?
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        updateText()
    }
    
    private func updateText() {
        
        let enabled = valueDidChange != nil
        vendorIDSourceTextField.isEnabled = enabled
        vendorIDTextField.isEnabled = enabled
        productIDTextField.isEnabled = enabled
        productVersionTextField.isEnabled = enabled
        
        vendorIDSourceTextField.text = "\(value.vendorIdSource.rawValue)"
        vendorIDTextField.text = "\(value.vendorId)"
        productIDTextField.text = "\(value.productId)"
        productVersionTextField.text = "\(value.productVersion)"
    }
}
