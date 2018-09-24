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
    
    let selectedService: NativeService
    let selectedCharacteristic: NativeCharacteristic
    
    private(set) var characteristicValue = Data() {
        
        didSet { showInfo() }
    }
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    init(selectedService: NativeService, selectedCharacteristic: NativeCharacteristic) {
        
        self.selectedCharacteristic = selectedCharacteristic
        self.selectedService = selectedService
        
        super.init(nibName: nil, bundle: nil)
    }
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    override func loadView() {
         self.view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        
    }
    
    private func showInfo(){
        
    }
    
    private func reloadData() {
        
        //let timeout = self.timeout
        
        let characteristicUUID = self.selectedCharacteristic.uuid
        let serviceUUID = self.selectedService.uuid
        let peripheral = self.selectedService.peripheral
        
        performActivity({
            
            try NativeCentral.shared.connect(to: peripheral)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let services = try NativeCentral.shared.discoverServices(for: peripheral)
            guard let service = services.first(where: { $0.uuid == serviceUUID })
                else { throw CentralError.unknownPeripheral }
            let characteristics = try NativeCentral.shared.discoverCharacteristics(for: service)
            guard let characteristic = characteristics.first(where: { $0.uuid == characteristicUUID })
                else { throw CentralError.unknownPeripheral }
            return try NativeCentral.shared.readValue(for: characteristic)
        }, completion: {
            $0.characteristicValue = $1
        })
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
    
    private func configureView() {
        
        self.title = self.selectedCharacteristic.uuid.description
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


