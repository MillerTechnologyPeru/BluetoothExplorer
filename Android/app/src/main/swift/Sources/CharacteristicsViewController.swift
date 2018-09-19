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
        
        let timeout = self.timeout
        
        performActivity({
            try NativeCentral.shared.connect(to: self.selectedService.peripheral)
            defer { NativeCentral.shared.disconnect(peripheral: self.selectedService.peripheral) }
            return try NativeCentral.shared.discoverCharacteristics(for: self.selectedService)
        }, completion: {
            $0.items = $1
        })
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

