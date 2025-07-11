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

@MainActor
internal final class MockCentral: CentralManager, @unchecked Sendable {
    
    /// Central Peripheral Type
    typealias Peripheral = GATT.Peripheral
    
    /// Central Advertisement Type
    typealias Advertisement = MockAdvertisementData
    
    /// Central Attribute ID (Handle)
    typealias AttributeID = UInt16
        
    nonisolated(unsafe) var log: (@Sendable (String) -> ())?
    
    var peripherals: [GATT.Peripheral : Bool] {
        get async {
            var peripherals = [Peripheral: Bool]()
            for scanData in state.scanData {
                peripherals[scanData.peripheral] = state.connected.contains(scanData.peripheral)
            }
            return peripherals
        }
    }
    
    var isEnabled: Bool {
        get async {
            state.isEnabled
        }
    }
    
    private var state = State()
    
    private var continuation = Continuation()
    
    init() { }
    
    /// Scans for peripherals that are advertising services.
    func scan(
        with services: Set<BluetoothUUID>,
        filterDuplicates: Bool
    ) -> AsyncCentralScan<MockCentral> {
        return AsyncCentralScan { continuation in
            await self.state.scanData.forEach {
                continuation($0)
            }
        }
    }
    
    func scan(
        filterDuplicates: Bool
    ) -> AsyncCentralScan<MockCentral> {
        scan(with: [], filterDuplicates: filterDuplicates)
    }
    
    /// Connect to the specified device
    func connect(to peripheral: Peripheral) async throws {
        state.connected.insert(peripheral)
    }
    
    /// Disconnect the specified device.
    func disconnect(_ peripheral: Peripheral) async {
        state.connected.remove(peripheral)
    }
    
    /// Disconnect all connected devices.
    func disconnectAll() {
        state.connected.removeAll()
    }
    
    /// Discover Services
    func discoverServices(
        _ services: Set<BluetoothUUID> = [],
        for peripheral: Peripheral
    ) async throws -> [Service<Peripheral, AttributeID>] {
        return state.characteristics
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
    nonisolated func discoverCharacteristics(
        _ characteristics: Set<BluetoothUUID> = [],
        for service: Service<Peripheral, AttributeID>
    ) async throws -> [Characteristic<Peripheral, AttributeID>] {
        guard await state.connected.contains(service.peripheral) else {
            throw CentralError.disconnected
        }
        guard let characteristics = await state.characteristics[service] else {
            throw CentralError.invalidAttribute(service.uuid)
        }
        return characteristics
            .sorted(by: { $0.id < $1.id })
    }
    
    /// Read Characteristic Value
    nonisolated func readValue(
        for characteristic: Characteristic<Peripheral, AttributeID>
    ) async throws -> Data {
        guard await state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return await state.characteristicValues[characteristic] ?? Data()
    }
    
    /// Write Characteristic Value
    nonisolated func writeValue(
        _ data: Data,
        for characteristic: Characteristic<Peripheral, AttributeID>,
        withResponse: Bool = true
    ) async throws {
        guard await state.connected.contains(characteristic.peripheral) else {
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
        await updateState { state in
            state.characteristicValues[characteristic] = data
        }
    }
    
    /// Discover descriptors
    nonisolated func discoverDescriptors(
        for characteristic: Characteristic<Peripheral, AttributeID>
    ) async throws -> [Descriptor<Peripheral, AttributeID>] {
        guard await state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return await state.descriptors[characteristic] ?? []
    }
    
    /// Read descriptor
    nonisolated func readValue(
        for descriptor: Descriptor<Peripheral, AttributeID>
    ) async throws -> Data {
        guard await state.connected.contains(descriptor.peripheral) else {
            throw CentralError.disconnected
        }
        return await state.descriptorValues[descriptor] ?? Data()
    }
    
    /// Write descriptor
    nonisolated func writeValue(
        _ data: Data,
        for descriptor: Descriptor<Peripheral, AttributeID>
    ) async throws {
        guard await state.connected.contains(descriptor.peripheral) else {
            throw CentralError.disconnected
        }
        await updateState { state in
            state.descriptorValues[descriptor] = data
        }
    }
    
    nonisolated func notify(
        for characteristic: GATT.Characteristic<GATT.Peripheral, AttributeID>
    ) async throws -> AsyncCentralNotifications<MockCentral> {
        guard await state.connected.contains(characteristic.peripheral) else {
            throw CentralError.disconnected
        }
        return AsyncCentralNotifications { [unowned self] continuation in
            if let notifications = await self.state.notifications[characteristic] {
                for notification in notifications {
                    if #available(iOS 16.0, *) {
                        try await Task.sleep(for: .seconds(1))
                    }
                    continuation(notification)
                }
            }
        }
    }
    
    /// Read MTU
    func maximumTransmissionUnit(for peripheral: Peripheral) async throws -> MaximumTransmissionUnit {
        guard state.connected.contains(peripheral) else {
            throw CentralError.disconnected
        }
        return .default
    }
    
    // Read RSSI
    func rssi(for peripheral: Peripheral) async throws -> RSSI {
        return .init(rawValue: 127)!
    }
}

private extension MockCentral {
    
    func updateState(_ body: (inout State) -> ()) {
        body(&state)
    }
}

internal extension MockCentral {
    
    struct State {
        var isEnabled = false
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
    }
}
#endif
