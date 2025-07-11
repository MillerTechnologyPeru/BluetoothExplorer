//
//  Store.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
@preconcurrency import Combine
import SwiftUI
import Bluetooth
import GATT

/// Store
@MainActor
@Observable
public final class Store: @unchecked Sendable {
    
    public typealias Central = NativeCentral
    
    public typealias Peripheral = Central.Peripheral
    
    public typealias ScanData = GATT.ScanData<Central.Peripheral, Central.Advertisement>
    
    public typealias Service = GATT.Service<Central.Peripheral, Central.AttributeID>
    
    public typealias Characteristic = GATT.Characteristic<Central.Peripheral, Central.AttributeID>
    
    public typealias Descriptor = GATT.Descriptor<Central.Peripheral, Central.AttributeID>
    
    public typealias ScanResult = ScanDataCache<Central.Peripheral, Central.Advertisement>
    
    // MARK: - Properties
    
    public private(set) var activity = [Peripheral: Bool]()
    
    public private(set) var isEnabled = false
    
    public private(set) var scanResults = [Peripheral: ScanResult]()
    
    public var isScanning: Bool {
        self.scanStream?.isScanning ?? false
    }
    
    public private(set) var connected: Set<Peripheral> = []
    
    public private(set) var services = [Peripheral: [Service]]()
    
    public private(set) var characteristics = [Service: [Characteristic]]()
    
    public private(set) var includedServices = [Service: [Service]]()

    public private(set) var descriptors = [Characteristic: [Descriptor]]()

    public private(set) var characteristicValues = [Characteristic: Cache<AttributeValue>]()

    public private(set) var descriptorValues = [Descriptor: Cache<AttributeValue>]()

    public private(set) var isNotifying = [Characteristic: Bool]()
    
    internal let central: Central
    
    private var scanStream: AsyncCentralScan<NativeCentral>?
        
    // MARK: - Initialization
    
    public init(central: Central = Central()) {
        self.central = central
        setupLog()
        observeValues()
    }
        
    // MARK: - Methods
    
    private func setupLog() {
        central.log = { print("Central: \($0)") }
    }
    
    private func observeValues() {
        Task { [weak self] in
            do {
                while let self {
                    try await Task.sleep(for: .seconds(1))
                    await self.updateState()
                }
            }
            catch {
                
            }
        }
    }
    
    private func updateState() async {
        assert(Thread.isMainThread)
        let oldValue = self.isEnabled
        let newValue = await self.central.isEnabled
        guard newValue != oldValue else {
            return
        }
        // update value
        self.isEnabled = newValue
        // start scanning when powered on
        guard newValue else {
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
    
    public func scan(
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
            self.scanStream = nil
        }
    }
    
    /// Cache discovered values
    private func found(scanData: ScanData) async {
        var cache = scanResults[scanData.peripheral] ?? ScanDataCache(scanData: scanData)
        cache += scanData
        #if os(Android)
        
        #elseif os(iOS) && targetEnvironment(simulator)
        
        #elseif canImport(CoreBluetooth)
        cache.name = try? await central.name(for: scanData.peripheral)
        for serviceUUID in scanData.advertisementData.overflowServiceUUIDs ?? [] {
            cache.overflowServiceUUIDs.insert(serviceUUID)
        }
        #endif
        scanResults[scanData.peripheral] = cache
    }
    
    public func stopScan() async {
        scanStream?.stop()
        scanStream = nil
    }
    
    public func connect(to peripheral: Central.Peripheral) async throws {
        activity[peripheral] = true
        defer { activity[peripheral] = false }
        if isScanning {
            scanStream?.stop()
        }
        try await central.connect(to: peripheral)
    }
    
    public func disconnect(_ peripheral: Central.Peripheral) async {
        await central.disconnect(peripheral)
    }
    
    public func discoverServices(for peripheral: Central.Peripheral) async throws {
        activity[peripheral] = true
        defer { activity[peripheral] = false }
        let services = try await central.discoverServices(for: peripheral)
        assert(Thread.isMainThread)
        self.services[peripheral] = services
    }
    
    public func discoverCharacteristics(for service: Service) async throws {
        activity[service.peripheral] = true
        defer { activity[service.peripheral] = false }
        let characteristics = try await central.discoverCharacteristics([], for: service)
        assert(Thread.isMainThread)
        self.characteristics[service] = characteristics
    }
    
    public func discoverIncludedServices(for service: Service) async throws {
        activity[service.peripheral] = true
        defer { activity[service.peripheral] = false }
        let includedServices = try await central.discoverIncludedServices(for: service)
        assert(Thread.isMainThread)
        self.includedServices[service] = includedServices
    }
    
    public func discoverDescriptors(for characteristic: Characteristic) async throws {
        activity[characteristic.peripheral] = true
        defer { activity[characteristic.peripheral] = false }
        let includedServices = try await central.discoverDescriptors(for: characteristic)
        assert(Thread.isMainThread)
        self.descriptors[characteristic] = includedServices
    }
    
    public func readValue(for characteristic: Characteristic) async throws {
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
    
    public func writeValue(_ data: Data, for characteristic: Characteristic, withResponse: Bool = true) async throws {
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
    
    public func notify(_ isEnabled: Bool, for characteristic: Characteristic) async throws {
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
    
    public func readValue(for descriptor: Descriptor) async throws {
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
    
    public func writeValue(_ data: Data, for descriptor: Descriptor) async throws {
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

public struct ScanDataCache <Peripheral: Peer, Advertisement: AdvertisementData>: Equatable, Hashable {
    
    public var scanData: GATT.ScanData<Peripheral, Advertisement>
    
    /// GAP or advertised name
    public var name: String?
    
    /// Advertised name
    public var advertisedName: String?
    
    public var manufacturerData: GATT.ManufacturerSpecificData<Advertisement.Data>?
    
    /// This value is available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    public var txPowerLevel: Double?
    
    /// Service-specific advertisement data.
    public var serviceData = [BluetoothUUID: Advertisement.Data]()
    
    /// An array of service UUIDs
    public var serviceUUIDs = Set<BluetoothUUID>()
    
    /// An array of one or more ``BluetoothUUID``, representing Service UUIDs.
    public var solicitedServiceUUIDs = Set<BluetoothUUID>()
    
    /// An array of one or more ``BluetoothUUID``, representing Service UUIDs that were found in the “overflow” area of the advertisement data.
    public var overflowServiceUUIDs = Set<BluetoothUUID>()
    
    /// Advertised iBeacon
    public var beacon: AppleBeacon?
    
    public init(scanData: GATT.ScanData<Peripheral, Advertisement>) {
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
    
    public var id: Peripheral.ID {
        scanData.id
    }
}
