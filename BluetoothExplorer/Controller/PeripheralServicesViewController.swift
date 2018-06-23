//
//  PeripheralServicesViewController.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/20/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Bluetooth
import GATT

final class PeripheralServicesViewController: TableViewController {
    
    // MARK: - IB Outlets
    
    @IBOutlet private(set) var activityIndicatorBarButtonItem: UIBarButtonItem!
    
    // MARK: - Properties
    
    public var peripheral: PeripheralManagedObject!
    
    // MARK: - Loading
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadData()
    }
    
    // MARK: - Actions
    
    @IBAction func pullToRefresh(_ sender: UIRefreshControl) {
        
        reloadData()
    }
    
    // MARK: - Methods
    
    func configureView() {
        
        guard isViewLoaded else { return }
        
        guard let managedObject = self.peripheral
            else { assertionFailure(); return }
        
        self.title = managedObject.scanData.advertisementData.localName ?? managedObject.identifier
    }
    
    func reloadData() {
        
        guard let peripheral = self.peripheral
            else { fatalError("View controller not configured") }
        
        configureView()
        performActivity({ try DeviceStore.shared.discoverServices(for: peripheral) })
    }
    
    override func newFetchedResultController() -> NSFetchedResultsController<NSManagedObject> {
        
        guard let peripheral = self.peripheral
            else { fatalError("View controller not configured") }
        
        // configure fetched results controller
        let predicate = NSPredicate(format: "%K == %@",
                                    #keyPath(ServiceManagedObject.peripheral),
                                    peripheral)
        
        let sort = [NSSortDescriptor(key: #keyPath(ServiceManagedObject.uuid), ascending: true)]
        let context = DeviceStore.shared.managedObjectContext
        let fetchedResultsController = NSFetchedResultsController(ServiceManagedObject.self,
                                                                  delegate: self,
                                                                  predicate: predicate,
                                                                  sortDescriptors: sort,
                                                                  context: context)
        fetchedResultsController.fetchRequest.fetchBatchSize = 30
        
        return fetchedResultsController
    }
    
    private subscript (indexPath: IndexPath) -> ServiceManagedObject {
        
        guard let managedObject = self.fetchedResultsController?.object(at: indexPath) as? ServiceManagedObject
            else { fatalError("Invalid type") }
        
        return managedObject
    }
    
    private func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        
        let managedObject = self[indexPath]
                
        let attributes = managedObject.attributesView
        
        if let name = attributes.uuid.name {
            
            cell.textLabel?.text = name
            cell.detailTextLabel?.text = attributes.uuid.rawValue
            
        } else {
            
            cell.textLabel?.text = attributes.uuid.rawValue
            cell.detailTextLabel?.text = ""
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ServiceCell", for: indexPath)
        
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    // MARK: - Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let identifier = segue.identifier ?? ""
        
        switch identifier {
            
        case "showPeripheralCharacteristics":
            
            let viewController = segue.destination as! PeripheralCharacteristicsViewController
            viewController.service = self[tableView.indexPathForSelectedRow!]
            
        default: assertionFailure("Unknown segue \(segue)")
        }
    }
}

// MARK: - ActivityIndicatorViewController

extension PeripheralServicesViewController: ActivityIndicatorViewController {
    
    func showActivity() {
        
        self.view.endEditing(true)
        
        let isRefreshing = self.refreshControl?.isRefreshing ?? false
        
        if isRefreshing == false {
            
            self.activityIndicatorBarButtonItem.customView?.alpha = 1.0
        }
    }
    
    func hideActivity(animated: Bool = true) {
        
        let isRefreshing = self.refreshControl?.isRefreshing ?? false
        
        if isRefreshing {
            
            self.endRefreshing()
            
        } else {
            
            let duration: TimeInterval = animated ? 0.5 : 0.0
            
            UIView.animate(withDuration: duration) { [weak self] in
                
                self?.activityIndicatorBarButtonItem.customView?.alpha = 0.0
            }
        }
    }
}
