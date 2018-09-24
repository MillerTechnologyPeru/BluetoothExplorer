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
final class CharacteristicViewController: UITableViewController {
    
    typealias NativeService = Service<NativeCentral.Peripheral>
    typealias NativeCharacteristic = Characteristic<NativeCentral.Peripheral>
    
    // MARK: - Properties
    
    let service: NativeService
    let characteristic: NativeCharacteristic
    
    private(set) var characteristicValue = [Data]() {
        
        didSet { configureView() }
    }
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    // MARK: - Initialization
    
    init(service: NativeService, characteristic: NativeCharacteristic) {
        
        self.characteristic = characteristic
        self.service = service
        
        super.init(style: .grouped)
    }
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureView()
        
        self.readValue()
    }
    
    // MARK: - Methods
    
    private func configureView() {
        
        self.title = self.characteristic.uuid.description
        
        // configure table view
        
    }
    
    private func readValue() {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        guard characteristic.properties.contains(.read)
            else { return }
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral, timeout: timeout)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            return try NativeCentral.shared.readValue(for: characteristic, timeout: timeout)
        }, completion: {
            $0.characteristicValue.append($1)
        })
    }
    
    private func writeValue() {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        guard characteristic.properties.contains(.write)
            || characteristic.properties.contains(.writeWithoutResponse)
            else { return }
        
        let withResponse = characteristic.properties.contains(.writeWithoutResponse) ? false : true
        let newValue = Data() // FIXME:
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral, timeout: timeout)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            try NativeCentral.shared.writeValue(newValue, for: characteristic, withResponse: withResponse, timeout: timeout)
        })
    }
}

// MARK: - ActivityIndicatorViewController

extension CharacteristicViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        
    }
    
    func hideActivity(animated: Bool = true) {
        
        
    }
}

// MARK: - Supporting Types

private extension CharacteristicViewController {
    
    enum Cell {
        
        case uuid(UUID)
        case name(String)
        
        case value(Data)
        
        case property(GATT.CharacteristicProperty)
    }
}
