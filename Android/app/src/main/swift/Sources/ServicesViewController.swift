//
//  ServicesViewController.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 9/7/18.
//  Copyright © 2018 PureSwift. All rights reserved.
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
final class ServicesViewController: UITableViewController {
    
    typealias NativeScanData = ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>
    
    typealias NativeService = Service<NativeCentral.Peripheral>
    
    // MARK: - Properties
    
    let scanData: NativeScanData
    
    private(set) var items = [NativeService]() {
        
        didSet { self.tableView.reloadData() }
    }
    
    private let cellReuseIdentifier = "Cell"
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    // MARK: - Loading
    
    init(scanData: NativeScanData) {
        
        self.scanData = scanData
        
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
        #if os(Android) || os(macOS)
        refreshControl.addTarget(action: actionRefresh, for: UIControlEvents.valueChanged)
        #else
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: UIControlEvents.valueChanged)
        #endif
        
        self.refreshControl = refreshControl
        
        self.configureView()
        self.reloadData()
    }
    
    // MARK: - Actions
    
    #if os(iOS) || os(macOS)
    @objc func pullToRefresh() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            
            self?.reloadData()
        })
    }
    #endif
    
    // MARK: - Methods
    
    private subscript (indexPath: IndexPath) -> NativeService {
        
        @inline(__always)
        get { return self.items[indexPath.row] }
    }
    
    private func configureView() {
                
        self.title = self.scanData.advertisementData.localName ?? self.scanData.peripheral.identifier.description
    }
    
    private func reloadData() {
        
        let peripheral = self.scanData.peripheral
        let timeout = self.timeout
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            return try NativeCentral.shared.discoverServices([], for: peripheral, timeout: timeout)
        }, completion: {
            $0.items = $1
        })
    }
    
    private func endRefreshing() {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing == true {
            
            refreshControl.endRefreshing()
        }
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
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        #if os(iOS)
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        #endif
        
        let item = self[indexPath]
        
        log("Selected \(item.peripheral) \(item.uuid.description)")
        
        let viewController = CharacteristicsViewController(service: item)
        
        self.show(viewController, sender: self)
    }
}

// MARK: - ActivityIndicatorViewController

extension ServicesViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        
    }
    
    func hideActivity(animated: Bool = true) {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing {
            
            self.endRefreshing()
        }
    }
}
