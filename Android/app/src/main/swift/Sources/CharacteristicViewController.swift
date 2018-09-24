//
//  CharacteristicViewController.swift
//  BluetoothExplorerAndroid
//
//  Created by Marco Estrella on 9/21/18.
//

import Foundation
import Bluetooth
import GATT

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

/// Characteristic
final class CharacteristicViewController: UIViewController {
    
    typealias NativeService = Service<NativeCentral.Peripheral>
    typealias NativeCharacteristic = Characteristic<NativeCentral.Peripheral>
    
    // MARK: - Properties
    
    let service: NativeService
    let characteristic: NativeCharacteristic
    
    private(set) var characteristicValue = Data() {
        
        didSet { showInfo() }
    }
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    // MARK: - Initialization
    
    init(service: NativeService, characteristic: NativeCharacteristic) {
        
        self.characteristic = characteristic
        self.service = service
        
        super.init(nibName: nil, bundle: nil)
    }
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Loading
    
    override func loadView() {
        
         self.view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var label = UILabel.init(frame: CGRect.init(x: 0, y: 0, width: 250, height: 40))
        label.text = "I'am a test label"
        
        self.view.addSubview(label)
        
        var label2 = UILabel.init(frame: CGRect.init(x: 0, y: 50, width: 250, height: 40))
        label2.text = "I'am a test label 2"
        
        self.view.addSubview(label2)
        
        var label3 = UILabel.init(frame: CGRect.init(x: 0, y: 100, width: 250, height: 40))
        label3.text = "I'am a test label 3"
        
        self.view.addSubview(label3)
        
        self.configureView()
    }
    
    // MARK: - Methods
    
    private func configureView() {
        
        self.title = self.characteristic.uuid.description
    }
    
    private func showInfo() {
        
    }
    
    private func readValue() {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        performActivity({
            
            try NativeCentral.shared.connect(to: peripheral, timeout: timeout)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            return try NativeCentral.shared.readValue(for: characteristic, timeout: timeout)
        }, completion: {
            $0.characteristicValue = $1
        })
    }
}

// MARK: - ActivityIndicatorViewController

extension CharacteristicViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        
    }
    
    func hideActivity(animated: Bool = true) {
        
            //self.endRefreshing()
    }
}
