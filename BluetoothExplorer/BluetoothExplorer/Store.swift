//
//  Store.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Bluetooth
import GATT
import DarwinGATT

final class Store: BindableObject {
    
    // MARK: - Initialization
    
    static let shared = Store()
    
    init(central: NativeCentral = .shared) {
        self.central = central
        self.centralState = central.state
        self.central.stateChanged = { [weak self] in
            self?.centralState = $0
        }
    }
    
    // MARK: - Properties
    
    let didChange = PassthroughSubject<Store, Never>()
    
    let central: NativeCentral
    
    var filterDuplicates: Bool = false
    
    private let queue = DispatchQueue(label: "Store Queue")
    
    private(set) var operationState: OperationState = .idle {
        didSet {
            didChange.send(self)
            print("Operation State changed: \(oldValue) -> \(operationState)")
        }
    }
    
    #if canImport(DarwinGATT)
    private(set) var centralState: DarwinBluetoothState {
        didSet {
            didChange.send(self)
            print("Bluetooth State changed: \(oldValue) -> \(centralState)")
            if centralState == .poweredOn {
                scan()
            }
        }
    }
    
    #endif
    
    private(set) var scanResults: [Peripheral: ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>] = [:] {
        didSet { didChange.send(self) }
    }
    
    private var lastScanUpdate: Date?
    
    private var pendingScanResults: [Peripheral: ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>] = [:]
    
    private let scanResultsFlushInterval = 1.0
    
    // MARK: - Methods
    
    private func async <Result> (_ newState: OperationState,
                                 _ operation: @escaping (Store) throws -> (Result),
                                 completion: ((Store, Result) -> ())? = nil) {
        assert(newState != .idle, "Invalid target state")
        self.operationState = newState
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let result = try operation(self)
                DispatchQueue.main.async {
                    self.operationState = newState
                    completion?(self, result)
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.operationState = .idle
                    // FIXME: Show error alert
                    print("⚠️ Error: \(error.localizedDescription)")
                    dump(error)
                }
            }
        }
    }
    
    func scan() {
        
        self.scanResults.removeAll(keepingCapacity: true)
        self.lastScanUpdate = nil
        
        async(.scanning, {
            try $0.central.scan(filterDuplicates: $0.filterDuplicates) { [unowned self] in
                self.discovered($0)
            }
        })
    }
    
    private func discovered(_ scanData: ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let lastScanUpdate = self.lastScanUpdate {
                self.pendingScanResults[scanData.peripheral] = scanData
                if lastScanUpdate + self.scanResultsFlushInterval < Date() {
                    self.flushScanResults()
                    self.lastScanUpdate = Date()
                }
            } else {
                // insert first result
                self.scanResults[scanData.peripheral] = scanData
                self.lastScanUpdate = Date()
            }
        }
    }
    
    private func flushScanResults() {
        pendingScanResults.forEach {
            scanResults[$0] = $1
        }
        pendingScanResults.removeAll(keepingCapacity: true)
    }
    
    func stopScanning() {
        
        assert(Thread.current.isMainThread, "Should only be called from main thread")
        
        self.operationState = .idle
        self.central.stopScan()
        if pendingScanResults.isEmpty == false {
            flushScanResults()
        }
    }
}

enum OperationState {
    
    case idle
    case scanning
    case connecting
    case discoveringServices
    case discoveringCharacteristics
    case reading
    case writing
    case writeNotificationState
}
