//
//  CentralViewController.swift
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

/// Scans for nearby BLE devices.
final class CentralViewController: UITableViewController {
    
    typealias NativeScanData = ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>
    
    // MARK: - IB Outlets
    
    #if os(iOS)
    //@IBOutlet private(set) var activityIndicatorBarButtonItem: UIBarButtonItem!
    #endif
    
    // MARK: - Properties
    
    private(set) var items = [NativeScanData]()
    
    let scanDuration: TimeInterval = 5.0
    
    let filterDuplicates: Bool = false
    
    private let cellReuseIdentifier = "Cell"
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set title
        self.title = "Central"
        
        // setup table view
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        
        // add refresh control
        #if os(iOS)
        let refreshControl = UIRefreshControl(frame: .zero)
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        self.refreshControl = refreshControl
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadData()
    }
    
    // MARK: - Actions
    
    #if os(iOS)
    @IBAction func pullToRefresh(_ sender: UIRefreshControl) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in self?.reloadData() })
    }
    #endif
    
    // MARK: - Methods
    
    private subscript (indexPath: IndexPath) -> NativeScanData {
        
        @inline(__always)
        get { return self.items[indexPath.row] }
    }
    
    #if os(iOS)
    private final func endRefreshing() {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing == true {
            
            refreshControl.endRefreshing()
        }
    }
    #endif
    
    private func reloadData() {
        
        // clear table data
        self.items.removeAll()
        
        // scan
        let scanDuration = self.scanDuration
        let filterDuplicates = self.filterDuplicates
        
        let start = Date()
        let end = start + scanDuration
        
        performActivity({
            try NativeCentral.shared.scan(filterDuplicates: filterDuplicates,
                                          shouldContinueScanning: { Date() < end },
                                          foundDevice: { [weak self] (device) in mainQueue { self?.foundDevice(device) } })
        })
    }
    
    private func foundDevice(_ scanData: NativeScanData) {
        
        // remove old value
        if let index = self.items.index(where: { $0.peripheral == scanData.peripheral }) {
            
            self.items.remove(at: index)
        }
        
        // add item
        self.items.append(scanData)
        
        // sort
        self.items.sort(by: { $0.peripheral.identifier.description < $1.peripheral.identifier.description })
        
        // update table view
        self.tableView.reloadData()
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        cell.textLabel?.text = item.advertisementData.localName ?? item.peripheral.identifier.description
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
        
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        
        let item = self[indexPath]
        
        log("Selected \(item.peripheral) \(item.advertisementData.localName ?? "")")
        
    }
}

// MARK: - ActivityIndicatorViewController

extension CentralViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        
    }
    
    func hideActivity(animated: Bool = true) {
        
        #if os(iOS)
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing {
            
            self.endRefreshing()
        }
        #endif
    }
}
