//
//  InputTextView.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/27/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import UIKit

@IBDesignable
class InputTextView: NibDesignableView {
    
    typealias TextFieldEventClosure = (() -> Void)?
    typealias ValidationClosure = ((String) -> Validation)?
    
    // MARK: - Properties
    
    @IBOutlet weak var fieldLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBInspectable
    public var placeholder: String? {
        
        get { return textField.placeholder }
        set { textField.placeholder = newValue }
    }
    
    @IBInspectable
    public var fieldLabelText: String? {
        
        get { return fieldLabel.text }
        set { fieldLabel.text = newValue }
    }
    
    @IBInspectable
    public var value: String? {
        
        get { return textField.text }
        set { textField.text = newValue }
    }
    
    public var keyboardType: UIKeyboardType {
        
        get { return textField.keyboardType }
        set { textField.keyboardType = newValue }
    }
    
    public var isEnabled: Bool {
        
        get { return textField.isEnabled }
        set { textField.isEnabled = newValue }
    }
    
    private var validation: Validation = .none {
        didSet { updateView() }
    }
    
    var validator: ValidationClosure
    
    var onBeginEditing: TextFieldEventClosure
    var onEndEditing: TextFieldEventClosure
    var onPressReturn: TextFieldEventClosure
    var onChange: TextFieldEventClosure
    
    public enum Validation {
        case none
        case error(String?)
    }
    
    // MARK: - Initializers
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    // MARK: - Methods
    
    private func setup() {
        
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    private func updateView() {
        
        switch validation {
        case .error(let message):
            messageLabel.text = message
            messageLabel.textColor = .red
            
        case .none:
            messageLabel.text = ""
        }
    }
    
    private func updateValidation() {
        
        validation = validator?(textField.text ?? "") ?? .none
    }
    
}

extension InputTextView: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        onBeginEditing?()
        updateValidation()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        onEndEditing?()
        updateValidation()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        onPressReturn?()
        updateValidation()
        return false
    }
    
    @objc open func textFieldDidChange(_ textField: UITextField) {
        
        onChange?()
        updateValidation()
    }
}
