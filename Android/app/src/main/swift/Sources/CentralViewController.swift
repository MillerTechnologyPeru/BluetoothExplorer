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
import AndroidBluetooth
import AndroidUIKit
#endif

/// Scans for nearby BLE devices.
final class CentralViewController: UITableViewController {
        
    // MARK: - Properties
    
    #if os(iOS)
    lazy var activityIndicator: UIActivityIndicatorView = self.loadActivityIndicatorView()
    #else
    lazy var progressDialog: AndroidProgressDialog = {
        let progressDialog = AndroidProgressDialog(context: UIApplication.shared.androidActivity)
        progressDialog.setIndeterminate(true)
        progressDialog.setTitle("Wait")
        progressDialog.setMessage("Scanning...")
        return progressDialog
    }()
    #endif
    
    private(set) var items = [NativeScanData]()
    
    let scanDuration: TimeInterval = 5.0
    
    let filterDuplicates: Bool = false
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set title
        self.title = "Central"
        
        // setup table view
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        #if os(iOS)
        self.tableView.register(ScanDataTableViewCell.self)
        #else
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        #endif
        
        let refreshControl = UIRefreshControl(frame: .zero)
        
        #if os(Android) || os(macOS)
        refreshControl.addTarget(action: { [unowned self] in self.reloadData() }, for: .valueChanged)
        #else
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        #endif
        
        self.refreshControl = refreshControl
        
        #if os(Android) || os(macOS)
        AndroidAppDelegate.shared.bluetoothEnabled = { [weak self] in self?.reloadData() }
        reloadData()
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadData()
    }
    
    // MARK: - Actions
    
    #if os(iOS)
    @objc func pullToRefresh(_ sender: UIRefreshControl) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            
            self?.reloadData()
        })
    }
    #endif
    
    
    // MARK: - Methods
    
    private subscript (indexPath: IndexPath) -> NativeScanData {
        
        @inline(__always)
        get { return self.items[indexPath.row] }
    }
    
    private final func endRefreshing() {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing{
            
            refreshControl.endRefreshing()
        }
    }
    
    private func reloadData() {
        
        log("\(type(of: self)) \(#function)")
        
        // clear table data
        self.items.removeAll()
        tableView.reloadData()
        
        // make sure its enabled
        #if os(Android)
        guard AndroidCentral.shared.hostController.isEnabled()
            else { return } // wait until enabled
        #endif
        
        // scan
        let scanDuration = self.scanDuration
        let filterDuplicates = self.filterDuplicates
        
        performActivity({
            try NativeCentral.shared.scan(duration: scanDuration, filterDuplicates: filterDuplicates) { [weak self] (device) in mainQueue { self?.foundDevice(device) } }
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
        self.items.sort(by: { $0.peripheral.description < $1.peripheral.description })
        
        // update table view
        self.tableView.reloadData()
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        #if os(iOS)
        
        cell.textLabel?.text = item.advertisementData.localName ?? item.peripheral.identifier.description
        cell.textLabel?.numberOfLines = 0
        
        #elseif os(Android) || os(macOS)
        
        if let localName = item.advertisementData.localName {
            
            let layoutName = "peripheral_item"
            
            if cell.layoutName != layoutName {
                cell.inflateAndroidLayout(layoutName)
            }
            
            let itemView = cell.androidView
            
            let tvNameId = UIApplication.shared.androidActivity.getIdentifier(name: "tvName", type: "id")
            let tvAddressId = UIApplication.shared.androidActivity.getIdentifier(name: "tvAddress", type: "id")
            
            guard let tvNameObject = itemView.findViewById(tvNameId)
                else { fatalError("No view for \(tvNameId)") }
            
            guard let tvAddressObject = itemView.findViewById(tvAddressId)
                else { fatalError("No view for \(tvAddressId)") }
            
            let tvName = Android.Widget.TextView(casting: tvNameObject)
            let tvAddress = Android.Widget.TextView(casting: tvAddressObject)
            
            tvName?.text = localName
            tvAddress?.text = item.peripheral.description
            
        } else {
            
            let layoutName = "peripheral_item_2"
            
            if cell.layoutName != layoutName {
                cell.inflateAndroidLayout(layoutName)
            }
            
            let itemView = cell.androidView
            
            let tvAddressId = UIApplication.shared.androidActivity.getIdentifier(name: "tvAddress", type: "id")
            
            guard let tvAddressObject = itemView.findViewById(tvAddressId)
                else { fatalError("No view for \(tvAddressId)") }
            
            let tvAddress = Android.Widget.TextView(casting: tvAddressObject)
            
            tvAddress?.text = item.peripheral.description
        }
        
        #endif
    }
    
    #if os(iOS)
    private func loadActivityIndicatorView() -> UIActivityIndicatorView {
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.frame.origin = CGPoint(x: 6.5, y: 15)
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 33, height: 44))
        view.backgroundColor = .clear
        view.addSubview(activityIndicator)
        
        let barButtonItem = UIBarButtonItem(customView: view)
        self.navigationItem.rightBarButtonItem = barButtonItem
        return activityIndicator
    }
    #endif
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(ScanDataTableViewCell.self, for: indexPath)
        configure(cell: cell, at: indexPath)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        #if os(iOS)
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        #endif
        
        let item = self[indexPath]
        
        self.endRefreshing()
        
        log("Selected \(item.peripheral) \(item.advertisementData.localName ?? "")")
        
        let viewController = ServicesViewController(scanData: item)
        
        self.show(viewController, sender: self)
    }
}

// MARK: - ActivityIndicatorViewController

extension CentralViewController: TableViewActivityIndicatorViewController { }
