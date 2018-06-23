//
//  DeviceStore.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/15/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import CoreData
import CoreBluetooth
import Bluetooth
import GATT

public final class DeviceStore {
    
    // MARK: - Properties
    
    /// The managed object context used for caching.
    public let managedObjectContext: NSManagedObjectContext
    
    /// The Bluetooth Low Energy GATT Central this `Store` will use for device requests.
    public let centralManager: CentralManager
        
    /// A convenience variable for the managed object model.
    private let managedObjectModel: NSManagedObjectModel
    
    /// Block for creating the persistent store.
    private let createPersistentStore: (NSPersistentStoreCoordinator) throws -> NSPersistentStore
    
    /// Block for resetting the persistent store.
    private let deletePersistentStore: (NSPersistentStoreCoordinator, NSPersistentStore?) throws -> ()
    
    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    private var persistentStore: NSPersistentStore
    
    /// The managed object context running on a background thread for asyncronous caching.
    private let privateQueueManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    private lazy var centralIdentifier: String = {
        
        return self.centralManager.identifier ?? "org.pureswift.GATT.CentralManager.default"
    }()
    
    // MARK: - Initialization
    
    deinit {
        
        // stop recieving 'didSave' notifications from private context
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSManagedObjectContextDidSave, object: self.privateQueueManagedObjectContext)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    public init(contextConcurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType,
                createPersistentStore: @escaping (NSPersistentStoreCoordinator) throws -> NSPersistentStore,
                deletePersistentStore: @escaping (NSPersistentStoreCoordinator, NSPersistentStore?) throws -> (),
                centralManager: CentralManager) throws {
        
        // store values
        self.createPersistentStore = createPersistentStore
        self.deletePersistentStore = deletePersistentStore
        self.centralManager = centralManager
        
        // set managed object model
        self.managedObjectModel = DeviceStore.managedObjectModel
        self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        
        // setup managed object contexts
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: contextConcurrencyType)
        self.managedObjectContext.undoManager = nil
        self.managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        self.privateQueueManagedObjectContext.undoManager = nil
        self.privateQueueManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        self.privateQueueManagedObjectContext.name = "\(type(of: self)) Private Managed Object Context"
        
        // configure CoreData backing store
        self.persistentStore = try createPersistentStore(persistentStoreCoordinator)
        
        // listen for notifications (for merging changes)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DeviceStore.mergeChangesFromContextDidSaveNotification(_:)),
                                               name: NSNotification.Name.NSManagedObjectContextDidSave,
                                               object: self.privateQueueManagedObjectContext)
        
        // update cache
        resetPeripherals()
    }
    
    // MARK: Requests
    
    /// The default Central managed object.
    public var central: CentralManagedObject {
        
        let context = privateQueueManagedObjectContext
        
        let centralIdentifier = self.centralIdentifier
        
        do {
            
            let managedObjectID: NSManagedObjectID = try context.performErrorBlockAndWait {
                
                let managedObject = try CentralManagedObject.findOrCreate(centralIdentifier, in: context)
                
                if managedObject.objectID.isTemporaryID {
                    
                    try context.save()
                }
                
                return managedObject.objectID
            }
            
            assert(managedObjectID.isTemporaryID == false, "Managed object \(managedObjectID) should be persisted")
            
            return managedObjectContext.object(with: managedObjectID) as! CentralManagedObject
        }
        
        catch { fatalError("Could not cache \(error)") }
    }
    
    /// Scans for nearby devices.
    ///
    /// - Parameter duration: The duration of the scan.
    public func scan(duration: TimeInterval, filterDuplicates: Bool = true) throws {
        
        let end = Date() + duration
        
        let centralIdentifier = self.centralIdentifier
        
        var oldPeripherals: [NSManagedObjectID] = updateCache {
            
            let fetchRequest = PeripheralManagedObject.fetchRequest()
            
            fetchRequest.predicate = NSPredicate(format: "%K == %@",
                                                 #keyPath(PeripheralManagedObject.isAvailible),
                                                 true as NSNumber)
            
            fetchRequest.includesSubentities = false
            fetchRequest.returnsObjectsAsFaults = true
            fetchRequest.resultType = .managedObjectIDResultType
            
            return try $0.fetch(fetchRequest) as! [NSManagedObjectID]
        }
        
        try centralManager.scan(filterDuplicates: filterDuplicates, shouldContinueScanning: { Date() < end }, foundDevice: { [unowned self] (scanData) in
            
            self.updateCache {
                
                let central = try CentralManagedObject.findOrCreate(centralIdentifier, in: $0)
                
                let peripheral = try PeripheralManagedObject.findOrCreate(scanData.peripheral.identifier,
                                                                          in: $0)
                peripheral.isAvailible = true
                peripheral.isConnected = false
                peripheral.central = central
                peripheral.scanData.update(scanData)
                
                // remove from old peripherals
                if let index = oldPeripherals.index(of: peripheral.objectID) {
                    
                    oldPeripherals.remove(at: index)
                }
            }
        })
        
        // update old peripherals
        updateCache { (context) in
            
            oldPeripherals.forEach { context.delete(context.object(with: $0)) }
        }
    }
    
    public func discoverServices(for peripheralManagedObject: PeripheralManagedObject) throws {
        
        // perform BLE operation
        let peripheral = Peripheral(identifier: peripheralManagedObject.attributesView.identifier)
        
        let foundServices = try device(for: peripheral) {
            try centralManager.discoverServices(for: peripheral)
        }
        
        // cache
        let context = privateQueueManagedObjectContext
        
        do {
            
            try context.performErrorBlockAndWait {
                
                let peripheral = context.object(with: peripheralManagedObject.objectID) as! PeripheralManagedObject
                
                // insert new services
                let serviceManagedObjects: [ServiceManagedObject] = try foundServices.map {
                    let managedObject = try ServiceManagedObject.findOrCreate($0.uuid, peripheral: peripheral, in: context)
                    managedObject.isPrimary = $0.isPrimary
                    return managedObject
                }
                
                // remove old services
                peripheral.services
                    .filter { serviceManagedObjects.contains($0) == false }
                    .forEach { context.delete($0) }
                
                // save
                try context.save()
            }
        }
            
        catch {
            dump(error)
            assertionFailure("Could not cache")
            return
        }
    }
    
    public func discoverCharacteristics(for serviceManagedObject: ServiceManagedObject) throws {
        
        assert(serviceManagedObject.value(forKey: #keyPath(ServiceManagedObject.peripheral)) != nil, "Invalid service")
        
        // perform BLE operation
        let peripheral = Peripheral(identifier: serviceManagedObject.peripheral.attributesView.identifier)
        
        let foundCharacteristics: [CentralManager.Characteristic] = try device(for: peripheral) {
            
            let services = try centralManager.discoverServices(for: peripheral)
            
            guard let foundService = services.first(where: { $0.uuid.rawValue == serviceManagedObject.uuid })
                else { throw CentralError.invalidAttribute(serviceManagedObject.attributesView.uuid) }
            
            return try centralManager.discoverCharacteristics(for: foundService.uuid, peripheral: peripheral)
        }
        
        // cache
        let context = privateQueueManagedObjectContext
        
        do {
            
            try context.performErrorBlockAndWait {
                
                let service = context.object(with: serviceManagedObject.objectID) as! ServiceManagedObject
                
                // insert new characteristics
                let newManagedObjects: [CharacteristicManagedObject] = try foundCharacteristics.map {
                    let managedObject = try CharacteristicManagedObject.findOrCreate($0.uuid,
                                                                                     service: service,
                                                                                     in: context)
                    managedObject.properties = Int16($0.properties.rawValue)
                    return managedObject
                }
                
                // remove old characteristics
                service.characteristics
                    .filter { newManagedObjects.contains($0) == false }
                    .forEach { context.delete($0) }
                
                // save
                try context.save()
            }
        }
            
        catch {
            dump(error)
            assertionFailure("Could not cache")
            return
        }
    }
    
    public func readValue(for characteristicManagedObject: CharacteristicManagedObject) throws {
        
        let serviceManagedObject = characteristicManagedObject.service
        
        assert(serviceManagedObject.value(forKey: #keyPath(ServiceManagedObject.peripheral)) != nil, "Invalid service")
        
        // perform BLE operation
        let peripheral = Peripheral(identifier: characteristicManagedObject.service.peripheral.attributesView.identifier)
        
        let value: Data = try device(for: peripheral) {
            
            let services = try centralManager.discoverServices(for: peripheral)
            
            guard let foundService = services.first(where: { $0.uuid.rawValue == serviceManagedObject.uuid })
                else { throw CentralError.invalidAttribute(serviceManagedObject.attributesView.uuid) }
            
            let characteristics = try centralManager.discoverCharacteristics(for: foundService.uuid,
                                                                             peripheral: peripheral)
            
            guard let foundCharacteristic = characteristics.first(where: { $0.uuid.rawValue == characteristicManagedObject.uuid })
                else { throw CentralError.invalidAttribute(characteristicManagedObject.attributesView.uuid) }
            
            return try centralManager.readValue(for: foundCharacteristic.uuid,
                                                service: foundService.uuid,
                                                peripheral: peripheral)
        }
        
        updateCache {
            
            let characteristic = $0.object(with: characteristicManagedObject.objectID) as! CharacteristicManagedObject
            
            characteristic.value = value
        }
    }
    
    public func writeValue(_ data: Data, withResponse: Bool = true, for characteristicManagedObject: CharacteristicManagedObject) throws {
        
        let serviceManagedObject = characteristicManagedObject.service
        
        assert(serviceManagedObject.value(forKey: #keyPath(ServiceManagedObject.peripheral)) != nil, "Invalid service")
        
        // perform BLE operation
        let peripheral = Peripheral(identifier: characteristicManagedObject.service.peripheral.attributesView.identifier)
        
        try device(for: peripheral) {
            
            let services = try centralManager.discoverServices(for: peripheral)
            
            guard let foundService = services.first(where: { $0.uuid.rawValue == serviceManagedObject.uuid })
                else { throw CentralError.invalidAttribute(serviceManagedObject.attributesView.uuid) }
            
            let characteristics = try centralManager.discoverCharacteristics(for: foundService.uuid,
                                                                             peripheral: peripheral)
            
            guard let foundCharacteristic = characteristics.first(where: { $0.uuid.rawValue == characteristicManagedObject.uuid })
                else { throw CentralError.invalidAttribute(characteristicManagedObject.attributesView.uuid) }
            
            try centralManager.writeValue(data,
                                          for: foundCharacteristic.uuid,
                                          withResponse: withResponse,
                                          service: foundService.uuid,
                                          peripheral: peripheral)
        }
        
        updateCache {
            
            let characteristic = $0.object(with: characteristicManagedObject.objectID) as! CharacteristicManagedObject
            
            characteristic.value = data
        }
    }
    
    // MARK: - Private Methods
    
    private func resetPeripherals() {
        
        updateCache {
            
            // mark all peripherals as unavailible
            try $0.all(PeripheralManagedObject.self).forEach {
                $0.isAvailible = false
                $0.isConnected = false
            }
        }
    }
    
    private func updateCache <T> (_ update: @escaping (NSManagedObjectContext) throws -> T) -> T {
        
        let context = self.privateQueueManagedObjectContext
        
        do {
            
            return try context.performErrorBlockAndWait {
                
                // fetch, insert, delete or update managed objects
                let result = try update(context)
                
                // save context
                try context.save()
                
                return result
            }
        }
        
        catch {
            dump(error)
            fatalError("Could not save CoreData context \(context) \(error)")
        }
    }
    
    /// Connects to the device, fetches the data, and performs the action, and disconnects.
    private func device <T> (for peripheral: Peripheral, _ action: () throws -> (T)) throws -> T {
        
        // connect first
        try centralManager.connect(to: peripheral)
        
        let managedObject: PeripheralManagedObject = updateCache {
            let managedObject = try PeripheralManagedObject.findOrCreate(peripheral.identifier, in: $0)
            managedObject.isConnected = true
            return managedObject
        }
        
        defer {
            centralManager.disconnect(peripheral: peripheral)
            updateCache { _ in managedObject.isConnected = false }
        }
        
        // perform action
        return try action()
    }
    
    // MARK: Notifications
    
    @objc private func mergeChangesFromContextDidSaveNotification(_ notification: Notification) {
        
        self.managedObjectContext.performAndWait {
            
            self.managedObjectContext.mergeChanges(fromContextDidSave: notification)
            
            // manually send notification
            NotificationCenter.default.post(name: .NSManagedObjectContextObjectsDidChange,
                                            object: self.managedObjectContext,
                                            userInfo: notification.userInfo)
        }
    }
}


// MARK: - Extensions

public extension DeviceStore {
    
    public static var managedObjectModel: NSManagedObjectModel {
        
        guard let fileURL = Bundle(for: self).url(forResource: "Model", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: fileURL)
            else { fatalError("Could not load CoreData model file") }
        
        return model
    }
}

// MARK: - Singleton

public extension DeviceStore {
    
    /// The default store.
    public static var shared: DeviceStore {
        
        struct Static {
            
            static let store = try! DeviceStore(createPersistentStore: DeviceStore.createPersistentStore,
                                                deletePersistentStore: DeviceStore.deletePersistentStore,
                                                centralManager: CentralManager(options: [
                                                    CBCentralManagerOptionRestoreIdentifierKey:
                                                        Bundle.main.bundleIdentifier ?? "org.pureswift.GATT.CentralManager"
                                                    ]))
        }
        
        return Static.store
    }
    
    internal static let fileURL: URL = {
        
        let fileManager = FileManager.default
        
        // get cache folder
        
        let cacheURL = try! fileManager.url(for: .cachesDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
        
        
        // get app folder
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "org.pureswift.GATT"
        let folderURL = cacheURL.appendingPathComponent(bundleIdentifier, isDirectory: true)
        
        // create folder if doesnt exist
        var folderExists: ObjCBool = false
        if fileManager.fileExists(atPath: folderURL.path, isDirectory: &folderExists) == false
            || folderExists.boolValue == false {
            
            try! fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        let fileURL = folderURL.appendingPathComponent("GATT.sqlite", isDirectory: false)
        
        return fileURL
    }()
    
    internal static func createPersistentStore(_ coordinator: NSPersistentStoreCoordinator) throws -> NSPersistentStore {
        
        func createStore() throws -> NSPersistentStore {
            
            return try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                      configurationName: nil,
                                                      at: DeviceStore.fileURL,
                                                      options: nil)
        }
        
        do { return try createStore() }
            
        catch {
            
            // delete file
            try DeviceStore.deletePersistentStore(coordinator, nil)
            
            // try again
            return try createStore()
        }
    }
    
    internal static func deletePersistentStore(_ coordinator: NSPersistentStoreCoordinator, _ persistentStore: NSPersistentStore? = nil) throws {
        
        let url = self.fileURL
        
        if FileManager.default.fileExists(atPath: url.path) {
            
            // delete file
            try FileManager.default.removeItem(at: url)
        }
        
        if let persistentStore = persistentStore {
            
            try coordinator.remove(persistentStore)
        }
    }
}
