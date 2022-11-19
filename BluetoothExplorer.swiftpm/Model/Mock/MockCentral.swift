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
    
    lazy var state = AsyncStream<DarwinBluetoothState> { [unowned self]  in
        $0.yield(.poweredOn)
    }
    
    var log: ((String) -> ())?
    
    var peripherals: Set<GATT.Peripheral> {
        return Set(_state.scanData.lazy.map { $0.peripheral })
    }
    
    var _state = State()
    
    private var continuation = Continuation()
    
    init() { }
    
    /// Scans for peripherals that are advertising services.
    func scan(filterDuplicates: Bool) -> AsyncCentralScan<MockCentral> {
        return AsyncCentralScan { continuation in
            self._state.scanData.forEach {
                continuation($0)
            }
        }
    }
    
    /// Connect to the specified device
    func connect(to peripheral: Peripheral) async throws {
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
            .filter { $0.peripheral == peripheral }
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
    
    func notify(
        for characteristic: GATT.Characteristic<GATT.Peripheral, AttributeID>
    ) async throws -> AsyncCentralNotifications<MockCentral> {
        guard _state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return AsyncCentralNotifications { [unowned self] continuation in
            if let notifications = self._state.notifications[characteristic] {
                for notification in notifications {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    continuation(notification)
                }
            }
        }
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
        var scanData: [MockScanData] = [.beacon, .smartThermostat]
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
            ],
            .savantSystems: [
                .savantTest
            ]
        ]
        var descriptors: [MockCharacteristic: [MockDescriptor]] = [
            .batteryLevel: [.clientCharacteristicConfiguration(.beacon)],
            .savantTest: [.clientCharacteristicConfiguration(.smartThermostat)],
        ]
        var characteristicValues: [MockCharacteristic: Data] = [
            .deviceName: Data("iBeacon".utf8),
            .manufacturerName: Data("Apple Inc.".utf8),
            .modelNumber: Data("iPhone11.8".utf8),
            .serialNumber: Data(UUID().uuidString.utf8),
            .batteryLevel: Data([100]),
            .savantTest: Data(UUID().uuidString.utf8)
        ]
        var descriptorValues: [MockDescriptor: Data] = [
            .clientCharacteristicConfiguration(.beacon): Data([0x00]),
            .clientCharacteristicConfiguration(.smartThermostat): Data([0x00]),
        ]
        var notifications: [MockCharacteristic: [Data]] = [
            .batteryLevel: [
                Data([99]),
                Data([98]),
                Data([95]),
                Data([80]),
                Data([75]),
                Data([25]),
                Data([20]),
                Data([5]),
                Data([1]),
            ],
            .savantTest: [
                Data(UUID().uuidString.utf8),
                Data(UUID().uuidString.utf8),
                Data(UUID().uuidString.utf8),
                Data(UUID().uuidString.utf8),
            ]
        ]
    }
    
    struct Continuation {
        var scan: AsyncThrowingStream<ScanData<Peripheral, Advertisement>, Error>.Continuation?
        var isScanning: AsyncStream<Bool>.Continuation?
    }
}
#endif
