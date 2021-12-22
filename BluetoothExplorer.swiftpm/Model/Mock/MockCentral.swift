//
//  MockCentral.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

#if DEBUG
import Foundation
import Bluetooth
import GATT
import DarwinGATT

internal final class MockCentral: CentralManager {
    
    /// Central Peripheral Type
    typealias Peripheral = GATT.Peripheral
    
    /// Central Advertisement Type
    typealias Advertisement = MockAdvertisementData
    
    /// Central Attribute ID (Handle)
    typealias AttributeID = UInt16
    
    /// Disconnected peripheral callback
    lazy var didDisconnect = AsyncStream<Peripheral> { [unowned self] _ in
        // TODO:
        //self.continuation
    }
    
    lazy var state = AsyncStream<DarwinBluetoothState> { [unowned self]  in
        $0.yield(.poweredOn)
    }
    
    lazy var log = AsyncStream<String> { [unowned self] _ in
        //self.continuation
    }
    
    lazy var isScanning = AsyncStream<Bool> { [unowned self] in
        self.continuation.isScanning = $0
    }
    
    var _state = State()
    
    private var continuation = Continuation()
    
    init() { }
    
    /// Scans for peripherals that are advertising services.
    func scan(filterDuplicates: Bool) -> AsyncThrowingStream<ScanData<Peripheral, Advertisement>, Error> {
        _state.isScanning = true
        let _ = isScanning
        continuation.isScanning?.yield(true)
        return AsyncThrowingStream<ScanData<Peripheral, Advertisement>, Error> { continuation in
            _state.scanData.forEach {
                continuation.yield($0)
            }
            self.continuation.scan = continuation
        }
    }
    
    /// Stops scanning for peripherals.
    func stopScan() async {
        _state.isScanning = false
        let _ = isScanning
        continuation.isScanning?.yield(false)
        continuation.scan?.finish(throwing: nil)
        continuation.scan = nil
    }
    
    /// Connect to the specified device
    func connect(to peripheral: Peripheral) async throws {
        await stopScan()
        _state.connected.insert(peripheral)
    }
    
    /// Disconnect the specified device.
    func disconnect(_ peripheral: Peripheral) {
        _state.connected.remove(peripheral)
    }
    
    /// Disconnect all connected devices.
    func disconnectAll() {
        _state.connected.removeAll()
    }
    
    /// Discover Services
    func discoverServices(
        _ services: Set<BluetoothUUID> = [],
        for peripheral: Peripheral
    ) async throws -> [Service<Peripheral, AttributeID>] {
        return _state.characteristics
            .keys
            .sorted(by: { $0.id < $1.id })
    }
    
    public func discoverIncludedServices(
        _ services: Set<BluetoothUUID> = [],
        for service: Service<Peripheral, AttributeID>
    ) async throws -> [Service<Peripheral, AttributeID>] {
        return []
    }
    
    /// Discover Characteristics for service
    func discoverCharacteristics(
        _ characteristics: Set<BluetoothUUID> = [],
        for service: Service<Peripheral, AttributeID>
    ) async throws -> [Characteristic<Peripheral, AttributeID>] {
        guard _state.connected.contains(service.peripheral) else {
            throw CentralError.disconnected
        }
        guard let characteristics = _state.characteristics[service] else {
            throw CentralError.invalidAttribute(service.uuid)
        }
        return characteristics
            .sorted(by: { $0.id < $1.id })
    }
    
    /// Read Characteristic Value
    func readValue(
        for characteristic: Characteristic<Peripheral, AttributeID>
    ) async throws -> Data {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return _state.characteristicValues[characteristic] ?? Data()
    }
    
    /// Write Characteristic Value
    func writeValue(
        _ data: Data,
        for characteristic: Characteristic<Peripheral, AttributeID>,
        withResponse: Bool = true
    ) async throws {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        if withResponse {
            guard characteristic.properties.contains(.write) else {
                throw CentralError.invalidAttribute(characteristic.uuid)
            }
        } else {
            guard characteristic.properties.contains(.writeWithoutResponse) else {
                throw CentralError.invalidAttribute(characteristic.uuid)
            }
        }
        // write
        _state.characteristicValues[characteristic] = data
    }
    
    /// Discover descriptors
    func discoverDescriptors(
        for characteristic: Characteristic<Peripheral, AttributeID>
    ) async throws -> [Descriptor<Peripheral, AttributeID>] {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return _state.descriptors[characteristic] ?? []
    }
    
    /// Read descriptor
    func readValue(
        for descriptor: Descriptor<Peripheral, AttributeID>
    ) async throws -> Data {
        guard _state.connected.contains(descriptor.peripheral) else {
            throw CentralError.disconnected
        }
        return _state.descriptorValues[descriptor] ?? Data()
    }
    
    /// Write descriptor
    func writeValue(
        _ data: Data,
        for descriptor: Descriptor<Peripheral, AttributeID>
    ) async throws {
        guard _state.connected.contains(descriptor.peripheral) else {
            throw CentralError.disconnected
        }
        _state.descriptorValues[descriptor] = data
    }
    
    /// Start Notifications
    func notify(
        for characteristic: Characteristic<Peripheral, AttributeID>
    ) async throws -> AsyncThrowingStream<Data, Error> {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return AsyncThrowingStream<Data, Error> { continuation in
            self.continuation.notifications[characteristic] = continuation
            if let notifications = _state.notifications[characteristic] {
                Task {
                    for notification in notifications {
                        guard let continuation = self.continuation.notifications[characteristic] else {
                            break
                        }
                        continuation.yield(notification)
                        try! await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
        }
    }
    
    // Stop Notifications
    func stopNotifications(for characteristic: Characteristic<Peripheral, AttributeID>) async throws {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        continuation.notifications[characteristic]?.finish(throwing: nil)
        continuation.notifications[characteristic] = nil
    }
    
    /// Read MTU
    func maximumTransmissionUnit(for peripheral: Peripheral) async throws -> MaximumTransmissionUnit {
        guard _state.connected.contains(peripheral) else {
            throw CentralError.disconnected
        }
        return .default
    }
    
    // Read RSSI
    func rssi(for peripheral: Peripheral) async throws -> RSSI {
        return .init(rawValue: 127)!
    }
}

internal extension MockCentral {
    
    struct State {
        var isScanning = false
        var scanData: [MockScanData] = [.beacon]
        var connected = Set<Peripheral>()
        var characteristics: [MockService: [MockCharacteristic]] = [
            .deviceInformation: [
                .deviceName,
                .manufacturerName,
                .modelNumber,
                .serialNumber
            ],
            .battery: [
                .batteryLevel
            ]
        ]
        var descriptors: [MockCharacteristic: [MockDescriptor]] = [
            .batteryLevel: [.clientCharacteristicConfiguration]
        ]
        var characteristicValues: [MockCharacteristic: Data] = [
            .deviceName: Data("iBeacon".utf8),
            .manufacturerName: Data("Apple Inc.".utf8),
            .modelNumber: Data("iPhone11.8".utf8),
            .serialNumber: Data(UUID().uuidString.utf8),
            .batteryLevel: Data([100])
        ]
        var descriptorValues: [MockDescriptor: Data] = [
            .clientCharacteristicConfiguration: Data([0x00])
        ]
        var notifications: [MockCharacteristic: [Data]] = [
            .batteryLevel: [
                Data([99]),
                Data([98]),
                Data([97]),
                Data([96]),
                Data([95]),
                Data([80]),
                Data([75]),
                Data([55]),
                Data([50]),
                Data([45]),
                Data([35]),
                Data([25]),
                Data([20]),
                Data([5]),
                Data([1]),
            ]
        ]
    }
    
    struct Continuation {
        var scan: AsyncThrowingStream<ScanData<Peripheral, Advertisement>, Error>.Continuation?
        var isScanning: AsyncStream<Bool>.Continuation?
        var notifications = [MockCharacteristic: AsyncThrowingStream<Data, Error>.Continuation]()
    }
}
#endif
