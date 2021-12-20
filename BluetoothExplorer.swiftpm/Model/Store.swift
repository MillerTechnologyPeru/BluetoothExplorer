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

@MainActor
final class Store: ObservableObject {
    
    typealias Central = DarwinCentral
    
    // MARK: - Properties
    
    @Published
    private(set) var state: DarwinBluetoothState = .unknown
    
    @Published
    private(set) var scanResults = [Central.Peripheral: ScanData<Central.Peripheral, Central.Advertisement>]()
    
    @Published
    private(set) var isScanning = false
    
    @Published
    private(set) var connected = Set<Central.Peripheral>()
    
    @Published
    private(set) var services = [Central.Peripheral: [Service<Central.Peripheral, Central.AttributeID>]]()
    
    @Published
    private(set) var characteristics = [Service<Central.Peripheral, Central.AttributeID>: [Characteristic<Central.Peripheral, Central.AttributeID>]]()
    
    private let central: Central
    
    // MARK: - Initialization
    
    init(central: Central) {
        self.central = central
        observeValues()
    }
    
    static let shared = Store(central: .shared)
    
    // MARK: - Methods
    
    private func observeValues() {
        Task { [unowned self] in
            for await value in self.central.state {
                assert(Thread.isMainThread)
                self.state = value
                
                // start scanning when powered on
                guard state == .poweredOn else {
                    continue
                }
                do { try await self.scan() }
                catch { } // ignore error
            }
        }
        Task { [unowned self] in
            for await value in self.central.isScanning {
                assert(Thread.isMainThread)
                self.isScanning = value
            }
        }
        Task { [unowned self] in
            for await value in self.central.didDisconnect {
                assert(Thread.isMainThread)
                if self.connected.contains(value) {
                    self.connected.remove(value)
                }
            }
        }
    }
    
    func scan() async throws {
        scanResults.removeAll(keepingCapacity: true)
        let stream = central.scan(filterDuplicates: true)
        for try await scanData in stream {
            assert(Thread.isMainThread)
            scanResults[scanData.peripheral] = scanData
        }
    }
    
    func stopScan() async {
        await central.stopScan()
    }
    
    func connect(to peripheral: Central.Peripheral) async throws {
        if isScanning {
            await central.stopScan()
        }
        try await central.connect(to: peripheral)
        assert(Thread.isMainThread)
        connected.insert(peripheral)
    }
    
    func disconnect(_ peripheral: Central.Peripheral) {
        central.disconnect(peripheral)
    }
    
    func discoverServices(for peripheral: Central.Peripheral) async throws {
        let services = try await central.discoverServices(for: peripheral)
        assert(Thread.isMainThread)
        self.services[peripheral] = services
    }
    
    func discoverCharacteristics(for service: Service<Central.Peripheral, Central.AttributeID>) async throws {
        let characteristics = try await central.discoverCharacteristics([], for: service)
        assert(Thread.isMainThread)
        self.characteristics[service] = characteristics
    }
}
