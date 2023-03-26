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

/// Store
@MainActor
final class Store: ObservableObject {
    
    typealias Central = NativeCentral
    
    typealias Peripheral = Central.Peripheral
    
    typealias ScanData = GATT.ScanData<Central.Peripheral, Central.Advertisement>
    
    typealias Service = GATT.Service<Central.Peripheral, Central.AttributeID>
    
    typealias Characteristic = GATT.Characteristic<Central.Peripheral, Central.AttributeID>
    
    typealias Descriptor = GATT.Descriptor<Central.Peripheral, Central.AttributeID>
    
    typealias ScanResult = ScanDataCache<Central.Peripheral, Central.Advertisement>
    
    // MARK: - Properties
    
    @Published
    private(set) var activity = [Peripheral: Bool]()
    
    @Published
    private(set) var state: DarwinBluetoothState = .unknown
    
    @Published
    private(set) var scanResults = [Peripheral: ScanResult]()
    
    var isScanning: Bool {
        self.scanStream?.isScanning ?? false
    }
    
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
    
    @Published
    private(set) var characteristicValues = [Characteristic: Cache<AttributeValue>]()
    
    @Published
    private(set) var descriptorValues = [Descriptor: Cache<AttributeValue>]()
    
    @Published
    private(set) var isNotifying = [Characteristic: Bool]()
    
    internal let central: Central
    
    @Published
    private var scanStream: AsyncCentralScan<NativeCentral>?
    
    private var centralObserver: AnyCancellable?
    
    // MARK: - Initialization
    
    deinit {
        centralObserver?.cancel()
    }
    
    init(central: Central) {
        self.central = central
        observeValues()
        setupLog()
    }
    
    static let shared = Store(central: .shared)
    
    // MARK: - Methods
    
    private func setupLog() {
        central.log = { print("Central: \($0)") }
    }
    
    private func observeValues() {
        centralObserver = central.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                self.objectWillChange.send()
                Task { [unowned self] in
                    await self.updateState()
                    await self.updateConnected()
                }
            }
        
    }
    
    private func updateState() async {
        assert(Thread.isMainThread)
        let oldValue = self.state
        let newValue = await self.central.state
        guard newValue != oldValue else {
            return
        }
        // update value
        self.state = newValue
        // start scanning when powered on
        guard newValue == .poweredOn else {
            return
        }
        do { try await self.scan() }
        catch { } // ignore error
    }
    
    private func updateConnected() async {
        assert(Thread.isMainThread)
        let oldValue = self.connected
        let newValue = await Set(central.peripherals.compactMap { $0.value ? $0.key : nil })
        guard oldValue != newValue else {
            return
        }
        self.connected = newValue
    }
    
    func scan(
        with services: Set<BluetoothUUID> = [],
        filterDuplicates: Bool = true
    ) async throws {
        scanResults.removeAll(keepingCapacity: true)
        self.scanStream = nil // end previous scan
        let stream = central.scan(
            with: services,
            filterDuplicates: filterDuplicates
        )
        self.scanStream = stream
        Task {
            for try await scanData in stream {
                await found(scanData: scanData)
            }
        }
    }
    
    /// Cache discovered values
    private func found(scanData: ScanData) async {
        var cache = scanResults[scanData.peripheral] ?? ScanDataCache(scanData: scanData)
        cache += scanData
        #if canImport(CoreBluetooth)
        cache.name = try? await central.name(for: scanData.peripheral)
        for serviceUUID in scanData.advertisementData.overflowServiceUUIDs ?? [] {
            cache.serviceUUIDs.insert(serviceUUID)
        }
        #endif
        scanResults[scanData.peripheral] = cache
    }
    
    func stopScan() async {
        scanStream?.stop()
        scanStream = nil
    }
    
    func connect(to peripheral: Central.Peripheral) async throws {
        activity[peripheral] = true
        defer { activity[peripheral] = false }
        if isScanning {
            scanStream?.stop()
        }
        try await central.connect(to: peripheral)
        assert(Thread.isMainThread)
        connected.insert(peripheral)
    }
    
    func disconnect(_ peripheral: Central.Peripheral) async {
        await central.disconnect(peripheral)
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
    
    func readValue(for characteristic: Characteristic) async throws {
        activity[characteristic.peripheral] = true
        defer { activity[characteristic.peripheral] = false }
        let data = try await central.readValue(for: characteristic)
        assert(Thread.isMainThread)
        let value = AttributeValue(
            date: Date(),
            type: .read,
            data: data
        )
        self.characteristicValues[characteristic, default: .init(capacity: 10)].append(value)
    }
    
    func writeValue(_ data: Data, for characteristic: Characteristic, withResponse: Bool = true) async throws {
        activity[characteristic.peripheral] = true
        defer { activity[characteristic.peripheral] = false }
        try await central.writeValue(data, for: characteristic, withResponse: withResponse)
        assert(Thread.isMainThread)
        let value = AttributeValue(
            date: Date(),
            type: .write,
            data: data
        )
        self.characteristicValues[characteristic, default: .init(capacity: 10)].append(value)
    }
    
    func notify(_ isEnabled: Bool, for characteristic: Characteristic) async throws {
        activity[characteristic.peripheral] = true
        defer { activity[characteristic.peripheral] = false }
        if isEnabled {
            let stream = try await central.notify(for: characteristic)
            isNotifying[characteristic] = isEnabled
            Task.detached(priority: .low) { [unowned self] in
                for try await notification in stream {
                    await self.notification(notification, for: characteristic)
                }
            }
        } else {
            //try await central.stopNotifications(for: characteristic)
            isNotifying[characteristic] = false
        }
    }
    
    private func notification(_ data: Data, for characteristic: Characteristic) async {
        assert(Thread.isMainThread)
        let value = AttributeValue(
            date: Date(),
            type: .notification,
            data: data
        )
        self.characteristicValues[characteristic, default: .init(capacity: 10)].append(value)
    }
    
    func readValue(for descriptor: Descriptor) async throws {
        activity[descriptor.peripheral] = true
        defer { activity[descriptor.peripheral] = false }
        let data = try await central.readValue(for: descriptor)
        assert(Thread.isMainThread)
        let value = AttributeValue(
            date: Date(),
            type: .read,
            data: data
        )
        self.descriptorValues[descriptor, default: .init(capacity: 10)].append(value)
    }
    
    func writeValue(_ data: Data, for descriptor: Descriptor) async throws {
        activity[descriptor.peripheral] = true
        defer { activity[descriptor.peripheral] = false }
        try await central.writeValue(data, for: descriptor)
        assert(Thread.isMainThread)
        let value = AttributeValue(
            date: Date(),
            type: .write,
            data: data
        )
        self.descriptorValues[descriptor, default: .init(capacity: 10)].append(value)
    }
}

// MARK: - Supporting Types

struct ScanDataCache <Peripheral: Peer, Advertisement: AdvertisementData>: Equatable, Hashable {
    
    var scanData: GATT.ScanData<Peripheral, Advertisement>
    
    /// GAP or advertised name
    var name: String?
    
    /// Advertised name
    var advertisedName: String?
    
    var manufacturerData: GATT.ManufacturerSpecificData?
    
    /// This value is available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    var txPowerLevel: Double?
    
    /// Service-specific advertisement data.
    var serviceData = [BluetoothUUID: Data]()
    
    /// An array of service UUIDs
    var serviceUUIDs = Set<BluetoothUUID>()
    
    /// An array of one or more ``BluetoothUUID``, representing Service UUIDs.
    var solicitedServiceUUIDs = Set<BluetoothUUID>()
    
    /// An array of one or more ``BluetoothUUID``, representing Service UUIDs that were found in the “overflow” area of the advertisement data.
    var overflowServiceUUIDs = Set<BluetoothUUID>()
    
    /// Advertised iBeacon
    var beacon: AppleBeacon?
    
    init(scanData: GATT.ScanData<Peripheral, Advertisement>) {
        self.scanData = scanData
        self += scanData
    }
    
    static func += (cache: inout ScanDataCache, scanData: GATT.ScanData<Peripheral, Advertisement>) {
        cache.scanData = scanData
        cache.advertisedName = scanData.advertisementData.localName
        if cache.name == nil {
            cache.name = scanData.advertisementData.localName
        }
        cache.txPowerLevel = scanData.advertisementData.txPowerLevel
        if let beacon = scanData.advertisementData.beacon {
            cache.beacon = beacon
        } else {
            cache.manufacturerData = scanData.advertisementData.manufacturerData
        }
        for serviceUUID in scanData.advertisementData.serviceUUIDs ?? [] {
            cache.serviceUUIDs.insert(serviceUUID)
        }
        for (serviceUUID, serviceData) in scanData.advertisementData.serviceData ?? [:] {
            cache.serviceData[serviceUUID] = serviceData
        }
    }
}

extension ScanDataCache: Identifiable {
    
    var id: Peripheral.ID {
        scanData.id
    }
}
