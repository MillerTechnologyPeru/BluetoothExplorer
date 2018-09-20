//
//  CharacteristicsViewController.swift
//  BluetoothExplorerAndroid
//
//  Created by Marco Estrella on 9/18/18.
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

/// Services
final class CharacteristicsViewController: UITableViewController {
    
    typealias NativeService = Service<NativeCentral.Peripheral>
    typealias NativeCharacteristic = Characteristic<NativeCentral.Peripheral>
    
    let selectedService: NativeService
    
    private let cellReuseIdentifier = "Cell"
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    private(set) var items = [NativeCharacteristic]() {
        
        didSet { self.tableView.reloadData() }
    }
    
    // MARK: - Loading
    
    init(selectedService: NativeService) {
        
        self.selectedService = selectedService
        
        super.init(style: .plain)
    }
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup table view
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        
        // add refresh control
        
        let actionRefresh: () -> () = {
            
            self.reloadData()
        }
        
        let refreshControl = UIRefreshControl(frame: .zero)
        refreshControl.addTarget(action: actionRefresh, for: .valueChanged)
        self.refreshControl = refreshControl
        
        self.configureView()
        self.reloadData()
    }
    
    private subscript (indexPath: IndexPath) -> NativeCharacteristic {
        
        @inline(__always)
        get { return self.items[indexPath.row] }
    }
    
    private func endRefreshing() {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing == true {
            
            refreshControl.endRefreshing()
        }
    }
    
    private func configureView() {
        
        self.title = self.selectedService.uuid.description
    }
    
    private func reloadData() {
        
        //let timeout = self.timeout
        
        let serviceUUID = self.selectedService.uuid
        let peripheral = self.selectedService.peripheral
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let services = try NativeCentral.shared.discoverServices(for: peripheral)
            guard let service = services.first(where: { $0.uuid == serviceUUID })
                else { throw CentralError.unknownPeripheral }
            return try NativeCentral.shared.discoverCharacteristics(for: service)
        }, completion: {
            $0.items = $1
        })
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        cell.textLabel?.text = item.uuid.description
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
}

// MARK: - ActivityIndicatorViewController

extension CharacteristicsViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        
    }
    
    func hideActivity(animated: Bool = true) {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing {
            
            self.endRefreshing()
        }
    }
}

