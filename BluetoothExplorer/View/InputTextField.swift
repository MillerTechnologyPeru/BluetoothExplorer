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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addToolbar()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addToolbar()
    }
    
    func addToolbar() {
        
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
