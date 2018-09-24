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
    
    private var sections = [Section]()
    
    private(set) var characteristicValue = [Data]() {
        didSet { configureView() }
    }
    
    private var isNotifying = false {
        didSet { configureView() }
    }
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    // MARK: - Initialization
    
    init(service: NativeService, characteristic: NativeCharacteristic) {
        
        self.characteristic = characteristic
        self.service = service
        
        super.init(style: .grouped)
    }
    
    deinit {
        
        // just in case we didnt stop notifications
        NativeCentral.shared.disconnect(peripheral: characteristic.peripheral)
    }
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup table view
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellIdentifier.uuid.rawValue)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellIdentifier.name.rawValue)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellIdentifier.value.rawValue)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellIdentifier.property.rawValue)
        
        // update UI
        self.configureView()
        
        // attempt to read
        self.readValue()
    }
    
    // MARK: - Methods
    
    private subscript (indexPath: IndexPath) -> Item {
        
        @inline(__always)
        get { return self.sections[indexPath.section].items[indexPath.row] }
    }
    
    private func configureView() {
        
        title = self.characteristic.uuid.rawValue
        
        // configure table view
        
        sections = []
        
        do {
            
            var items = [Item]()
            
            if let name = characteristic.uuid.name {
                
                items.append(.name(name))
            }
            
            items.append(.uuid(characteristic.uuid))
            
            sections.append(Section(title: nil, items: items))
        }
        
        if characteristic.properties.isEmpty == false {
            
            sections.append(Section(title: "Properties", items: characteristic.properties.map { Item.property($0) }))
        }
        
        if characteristicValue.isEmpty == false {
            
            sections.append(Section(title: "Value", items: characteristicValue.reversed().map { Item.value($0) }))
        }
                
        // update UI
        tableView.reloadData()
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
    
    private func writeValue(_ newValue: Data, withResponse: Bool = true) {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral, timeout: timeout)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            try NativeCentral.shared.writeValue(newValue, for: characteristic, withResponse: withResponse, timeout: timeout)
        }, completion: { (viewController: CharacteristicViewController, _) in
            viewController.characteristicValue.append(newValue)
        })
    }
    
    private func startNotifications() {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            try NativeCentral.shared.notify({ [weak self] (newValue) in mainQueue { self?.notification(newValue) } }, for: characteristic)
        }, completion: { (viewController: CharacteristicViewController, _) in
            viewController.isNotifying = true
        })
    }
    
    private func notification(_ newValue: Data) {
        
        self.characteristicValue.append(newValue)
    }
    
    private func stopNotifications() {
        
        let timeout = self.timeout
        let service = self.service
        let characteristic = self.characteristic
        let peripheral = self.service.peripheral
        
        performActivity({
            // should already be connected
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            let _ = try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
            try NativeCentral.shared.notify(nil, for: characteristic)
        }, completion: { (viewController: CharacteristicViewController, _) in
            viewController.isNotifying = false
        })
    }
    
    private func configure(cell: UITableViewCell, with value: String) {
        
        cell.textLabel?.text = value
    }
    
    private func configure(cell: UITableViewCell, with data: Data) {
        
        cell.textLabel?.text = data.isEmpty ? "No value" : "0x" + data.reduce("", { $0 + String($1, radix: 16) })
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int {
        
        let section = self.sections[sectionIndex]
        
        return section.items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let item = self[indexPath]
        
        switch item {
        case let .uuid(uuid):
            let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.uuid.rawValue, for: indexPath)
            configure(cell: cell, with: uuid.rawValue)
            return cell
        case let .name(name):
            let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.name.rawValue, for: indexPath)
            configure(cell: cell, with: name)
            return cell
        case let .value(data):
            let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.value.rawValue, for: indexPath)
            configure(cell: cell, with: data)
            return cell
        case let .property(property):
            let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.property.rawValue, for: indexPath)
            configure(cell: cell, with: property.name)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return self.sections[section].title
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        #if os(iOS)
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        #endif
        
        let item = self[indexPath]
        
        switch item {
            
        case .uuid,
             .name:
            break
            
        case let .value(data):
            break // TODO: Show expanded data
            
        case let .property(property):
            
            switch property {
            case .broadcast,
                 .extendedProperties,
                 .signedWrite:
                break // cant handle
            case .read:
                readValue()
            case .write:
                // TODO: show UI to type new value
                writeValue(Data())
                break
            case .writeWithoutResponse:
                // TODO: show UI to type new value
                writeValue(Data(), withResponse: false)
                break
            case .notify,
                 .indicate:
                isNotifying ? stopNotifications() : startNotifications()
            }
        }
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
    
    struct Section {
        
        let title: String?
        let items: [Item]
    }
    
    enum Item {
        
        case uuid(BluetoothUUID)
        case name(String)
        case value(Data)
        case property(GATT.CharacteristicProperty)
    }
    
    enum CellIdentifier: String {
        
        case uuid
        case name
        case value
        case property
    }
}
