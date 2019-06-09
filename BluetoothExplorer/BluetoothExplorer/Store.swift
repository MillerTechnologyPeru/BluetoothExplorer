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

final class Store: BindableObject {
    
    // MARK: - Initialization
    
    static let shared = Store()
    
    init(central: NativeCentral = .shared) {
        self.central = central
    }
    
    // MARK: - Properties
    
    let didChange = PassthroughSubject<Store, Never>()
    
    let central: NativeCentral
    
    var filterDuplicates: Bool = false
    
    private let queue = DispatchQueue(label: "Store Queue")
    
    private(set) var state: BluetoothState = .idle {
        didSet { didChange.send(self) }
    }
    
    private(set) var scanResults: [Peripheral: ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>] = [:] {
        didSet { didChange.send(self) }
    }
    
    // MARK: - Methods
    
    private func async <Result> (_ newState: BluetoothState,
                                 operation: (Store) throws -> (Result),
                                 completion: ((Store, Result) -> ())? = nil) {
        assert(newState != .idle, "Invalid target state")
        self.state = newState
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let result = try operation(self)
                DispatchQueue.main.async {
                    self.state = newState
                    completion?(self, result)
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.state = .idle
                    // FIXME: Show error alert
                    print("⚠️ Error: \(error.localizedDescription)")
                    dump(error)
                }
            }
        }
    }
    
    func scan() {
        
        self.state = .scanning
        self.scanResults.removeAll(keepingCapacity: true)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.central.scan(filterDuplicates: self.filterDuplicates) { (scanData) in
                    DispatchQueue.main.async {
                        self.scanResults[scanData.peripheral] = scanData
                    }
                }
                DispatchQueue.main.async {
                    self.state = .idle
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.state = .idle
                }
            }
        }
    }
    
    func stopScanning() {
        
        self.central.stopScan()
        self.state = .idle
    }
}

enum BluetoothState {
    
    case idle
    case scanning
    case connecting
    case discoverServices
    case discoverCharacteristics
    case read
    case write
    case notificationState
}
