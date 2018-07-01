//
//  InputTextField.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/27/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit

class InputTextField: UITextField {
    
    // MARK: - Properties
    
    var posibleValues = [String]() {
        didSet {
            inputView = (posibleValues.count == 0) ? nil : pickerView
        }
    }
    
    private lazy var pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.delegate = self
        return picker
    }()
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addToolbar()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addToolbar()
    }
    
    // MARK: - Overrides
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return posibleValues.count == 0
    }
    
    // MARK: - Methods
    
    private func addToolbar() {
        
        let toolbar = UIToolbar()
        toolbar.isTranslucent = true
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAction))
        ]
        
        toolbar.sizeToFit()
        
        inputAccessoryView = toolbar
    }
    
    @objc func doneAction() {
        
        self.resignFirstResponder()
    }
    
}

extension InputTextField: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        return posibleValues.count
    }
    
}

extension InputTextField: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        return posibleValues[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        text = posibleValues[row]
    }
    
}
