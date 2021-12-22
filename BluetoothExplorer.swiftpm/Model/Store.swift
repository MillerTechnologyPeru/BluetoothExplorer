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
    
    typealias Peripheral = Central.Peripheral
    
    typealias ScanData = GATT.ScanData<Central.Peripheral, Central.Advertisement>
    
    typealias Service = GATT.Service<Central.Peripheral, Central.AttributeID>
    
    typealias Characteristic = GATT.Characteristic<Central.Peripheral, Central.AttributeID>
    
    typealias Descriptor = GATT.Descriptor<Central.Peripheral, Central.AttributeID>
    
    // MARK: - Properties
    
    @Published
    private(set) var activity = [Peripheral: Bool]()
    
    @Published
    private(set) var state: DarwinBluetoothState = .unknown
    
    @Published
    private(set) var scanResults = [Peripheral: ScanData]()
    
    @Published
    private(set) var isScanning = false
    
    @Published
    private(set) var connected = Set<Peripheral>()
    
    @Published
    private(set) var services = [Peripheral: [Service]]()
    
    @Published
    private(set) var characteristics = [Service: [Characteristic]]()
    
    @Published
    private(set) var includedServices = [Service: [Service]]()
    
    @Published
    private(set) var descriptors = [Characteristic: [Descriptor]]()
    
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
        activity[peripheral] = true
        defer { activity[peripheral] = false }
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
        activity[peripheral] = true
        defer { activity[peripheral] = false }
        let services = try await central.discoverServices(for: peripheral)
        assert(Thread.isMainThread)
        self.services[peripheral] = services
    }
    
    func discoverCharacteristics(for service: Service) async throws {
        activity[service.peripheral] = true
        defer { activity[service.peripheral] = false }
        let characteristics = try await central.discoverCharacteristics([], for: service)
        assert(Thread.isMainThread)
        self.characteristics[service] = characteristics
    }
    
    func discoverIncludedServices(for service: Service) async throws {
        activity[service.peripheral] = true
        defer { activity[service.peripheral] = false }
        let includedServices = try await central.discoverIncludedServices(for: service)
        assert(Thread.isMainThread)
        self.includedServices[service] = includedServices
    }
    
    func discoverDescriptors(for characteristic: Characteristic) async throws {
        activity[characteristic.peripheral] = true
        defer { activity[characteristic.peripheral] = false }
        let includedServices = try await central.discoverDescriptors(for: characteristic)
        assert(Thread.isMainThread)
        self.descriptors[characteristic] = includedServices
    }
}
