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

/// Characteristics
final class CharacteristicsViewController: UITableViewController {
    
    typealias NativeService = Service<NativeCentral.Peripheral>
    typealias NativeCharacteristic = Characteristic<NativeCentral.Peripheral>
    
    // MARK: - Properties
    
    #if os(iOS)
    lazy var activityIndicator: UIActivityIndicatorView = self.loadActivityIndicatorView()
    #else
    lazy var progressDialog: AndroidProgressDialog = {
        let progressDialog = AndroidProgressDialog(context: UIApplication.shared.androidActivity)
        progressDialog.setIndeterminate(true)
        progressDialog.setTitle("Wait")
        progressDialog.setMessage("Loading Characteristics...")
        return progressDialog
    }()
    #endif
    
    let service: NativeService
    
    private let cellReuseIdentifier = "Cell"
    
    private let timeout: TimeInterval = .gattDefaultTimeout
    
    private(set) var items = [NativeCharacteristic]() {
        
        didSet { self.tableView.reloadData() }
    }
    
    // MARK: - Initialization
    
    init(service: NativeService) {
        
        self.service = service
        
        super.init(style: .plain)
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
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        
        // add refresh control
        let refreshControl = UIRefreshControl(frame: .zero)

        #if os(Android) || os(macOS)
        refreshControl.addTarget(action: { [unowned self] in self.reloadData() }, for: .valueChanged)
        #else
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        #endif
        
        self.refreshControl = refreshControl
        
        self.configureView()
        self.reloadData()
    }
    
    // MARK: - Methods
    
    private subscript (indexPath: IndexPath) -> NativeCharacteristic {
        
        @inline(__always)
        get { return self.items[indexPath.row] }
    }
    
    #if os(iOS) || os(macOS)
    @objc func pullToRefresh() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            
            self?.reloadData()
        })
    }
    #endif
    
    private func endRefreshing() {
        
        if let refreshControl = self.refreshControl,
            refreshControl.isRefreshing == true {
            
            refreshControl.endRefreshing()
        }
    }
    
    private func configureView() {
        
        self.title = self.service.uuid.description
    }
    
    private func reloadData() {
        
        let timeout = self.timeout
        
        let service = self.service
        let peripheral = self.service.peripheral
        
        performActivity({
            try NativeCentral.shared.connect(to: peripheral)
            defer { NativeCentral.shared.disconnect(peripheral: peripheral) }
            let _ = try NativeCentral.shared.discoverServices(for: peripheral, timeout: timeout)
            return try NativeCentral.shared.discoverCharacteristics(for: service, timeout: timeout)
        }, completion: {
            $0.items = $1
        })
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let item = self[indexPath]
        
        cell.textLabel?.text = item.uuid.description
        
        #if os(iOS)
        cell.textLabel?.numberOfLines = 0
        #endif
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
        
        let characteristic = self[indexPath]
        
        log("Selected \(characteristic.uuid.description)")
        
        let viewController = CharacteristicViewController(service: service, characteristic: characteristic)
        
        self.show(viewController, sender: self)
    }
}

// MARK: - ActivityIndicatorViewController

extension CharacteristicsViewController: TableViewActivityIndicatorViewController { }
