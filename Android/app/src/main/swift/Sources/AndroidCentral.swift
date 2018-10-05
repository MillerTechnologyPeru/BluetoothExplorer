//
//  AndroidCentral.swift
//  Android
//
//  Created by Marco Estrella on 7/24/18.
//

import Foundation
import GATT
import Bluetooth

//#if os(android)

import Android
import java_swift
import java_util

public enum AndroidCentralError: Error {
    
    /// Bluetooth is disabled.
    case bluetoothDisabled
    
    /// Binder IPC failure.
    case binderFailure
    
    /// Characteristic not found
    case characteristicNotFound
    
    /// Unexpected null value.
    case nullValue(AnyKeyPath)
}

public final class AndroidCentral: CentralProtocol {

    // MARK: - Properties
    
    public var log: ((String) -> ())?
    
    public let hostController: Android.Bluetooth.Adapter
    
    public let context: Android.Content.Context
    
    public let options: Options
    
    internal private(set) var internalState = InternalState()
    
    internal lazy var accessQueue: DispatchQueue = DispatchQueue(label: "\(type(of: self)) Access Queue")
    
    // MARK: - Intialization
    
    deinit {
        
        
    }
    
    public init(hostController: Android.Bluetooth.Adapter,
                context: Android.Content.Context,
                options: AndroidCentral.Options = Options()) {
        
        self.hostController = hostController
        self.context = context
        self.options = options
    }
    
    // MARK: - Methods
    
    public func scan(filterDuplicates: Bool = true,
              shouldContinueScanning: () -> (Bool),
              foundDevice: @escaping (ScanData<Peripheral, AdvertisementData>) -> ()) throws {
        
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        guard let scanner = hostController.lowEnergyScanner
            else { throw AndroidCentralError.nullValue(\Android.Bluetooth.Adapter.lowEnergyScanner) }
        
        accessQueue.sync { [unowned self] in
            self.internalState.scan.peripherals.removeAll()
            self.internalState.scan.foundDevice = foundDevice
        }
        
        log?("Scanning...")
        
        let scanCallback = ScanCallback()
        scanCallback.central = self
        
        scanner.startScan(callback: scanCallback)
        
        // wait until finish scanning
        while shouldContinueScanning() { sleep(1) }
        
        scanner.stopScan(callback: scanCallback)
    }
    
    public func connect(to peripheral: Peripheral, timeout: TimeInterval = .gattDefaultTimeout) throws {
        
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        // store semaphore
        let semaphore = Semaphore(timeout: timeout)
        accessQueue.sync { [unowned self] in self.internalState.connect.semaphore = semaphore }
        defer { accessQueue.sync { [unowned self] in self.internalState.connect.semaphore = nil } }
        
        // attempt to connect (does not timeout)
        try accessQueue.sync { [unowned self] in
            
            guard let scanDevice = self.internalState.scan.peripherals[peripheral]
                else { throw CentralError.unknownPeripheral }
            
            let callback = GattCallback(central: self)
            
            let gatt: AndroidBluetoothGatt
            
            // call the correct method for connecting
            if Android.OS.Build.Version.Sdk.sdkInt.rawValue <= Android.OS.Build.VersionCodes.lollipopMr1 {
                
                gatt = scanDevice.scanResult.device.connectGatt(context: self.context,
                                                                autoConnect: false,
                                                                callback: callback)
            } else {
                
                gatt = scanDevice.scanResult.device.connectGatt(context: self.context,
                                                                autoConnect: false,
                                                                callback: callback,
                                                                transport: Android.Bluetooth.Device.Transport.le)
            }
            
            self.internalState.cache[peripheral] = Cache(gatt: gatt, callback: callback)
        }
        
        // throw async error
        do { try semaphore.wait() }
            
        catch CentralError.timeout {
            
            // cancel connection if we timeout
            accessQueue.sync { [unowned self] in
                
                // Close, disconnect or cancel connection
                self.internalState.cache[peripheral]?.gatt.disconnect()
                self.internalState.cache[peripheral] = nil
            }
            
            throw CentralError.timeout
        }
        
        // negotiate MTU
        let currentMTU = try self.maximumTransmissionUnit(for: peripheral)
        if options.maximumTransmissionUnit != currentMTU {
            
            log?("Current MTU is \(currentMTU), requesting \(options.maximumTransmissionUnit)")
            
            try request(mtu: options.maximumTransmissionUnit, for: peripheral)
        }
    }
    
    internal func request(mtu: ATTMaximumTransmissionUnit, for peripheral: Peripheral) throws {
        
        try accessQueue.sync { [unowned self] in
            
            guard let _ = self.internalState.scan.peripherals[peripheral]
                else { throw CentralError.unknownPeripheral }
            
            guard let cache = self.internalState.cache[peripheral]
                else { throw CentralError.disconnected }
            
            guard cache.gatt.requestMtu(mtu: Int(mtu.rawValue))
                else { throw AndroidCentralError.binderFailure }
        }
        
        // dont wait
    }
    
    public func disconnect(peripheral: Peripheral) {
        
        NSLog("\(type(of: self)) \(#function)")
        
        accessQueue.sync { [unowned self] in
            self.internalState.cache[peripheral]?.gatt.disconnect()
            //self.internalState.cache[peripheral]?.gatt.close()
            self.internalState.cache[peripheral] = nil
        }
    }
    
    public func disconnectAll() {
        
        NSLog("\(type(of: self)) \(#function)")
        
        accessQueue.sync { [unowned self] in
            self.internalState.cache.values.forEach {
                $0.gatt.disconnect()
            }
            self.internalState.cache.removeAll()
        }
    }
    
    public func discoverServices(_ services: [BluetoothUUID] = [],
                                 for peripheral: Peripheral,
                                 timeout: TimeInterval = .gattDefaultTimeout) throws -> [Service<Peripheral>] {
        
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        // store semaphore
        let semaphore = Semaphore(timeout: timeout)
        accessQueue.sync { [unowned self] in self.internalState.discoverServices.semaphore = semaphore }
        defer { accessQueue.sync { [unowned self] in self.internalState.discoverServices.semaphore = nil } }
        
        try accessQueue.sync { [unowned self] in
            
            guard self.internalState.scan.peripherals.keys.contains(peripheral)
                else { throw CentralError.unknownPeripheral }
            
            guard let cache = self.internalState.cache[peripheral]
                else { throw CentralError.disconnected }
            
            guard cache.gatt.discoverServices()
                else { throw AndroidCentralError.binderFailure }
        }
        
        // throw async error
        do { try semaphore.wait() }
        
        // get values from internal state
        return try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[peripheral]
                else { throw CentralError.unknownPeripheral }
            
            return cache.services.values.map { identifier, service in
                
                let uuid = BluetoothUUID(android: service.getUuid())
                
                let isPrimary = service.getType() == AndroidBluetoothGattService.ServiceType.primary
                
                let service = Service(identifier: identifier,
                                      uuid: uuid,
                                      peripheral: peripheral,
                                      isPrimary: isPrimary)
                
                return service
            }
        }
    }
    
    public func discoverCharacteristics(_ characteristics: [BluetoothUUID] = [],
                                        for service: Service<Peripheral>,
                                        timeout: TimeInterval = .gattDefaultTimeout) throws -> [Characteristic<Peripheral>] {
        
        NSLog("\(type(of: self)) \(#function)")
        
        return try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[service.peripheral]
                else { throw CentralError.disconnected }
            
            guard let gattService = cache.services.values[service.identifier]
                else { throw AndroidCentralError.binderFailure }
            
            let gattCharacteristics = gattService.getCharacteristics()
            
            internalState.cache[service.peripheral]?.update(gattCharacteristics, for: service)
            
            return internalState.cache[service.peripheral]!.characteristics.values.map { (identifier, characteristic) in
                
                let uuid = BluetoothUUID(android: characteristic.getUuid())
                
                let properties = BitMaskOptionSet<GATT.CharacteristicProperty>(rawValue: UInt8(characteristic.getProperties()))
                
                let characteristic = Characteristic<Peripheral>(identifier: identifier,
                                                                uuid: uuid,
                                                                peripheral: service.peripheral,
                                                                properties: properties)
                return characteristic
            }
        }
    }
    
    public func readValue(for characteristic: Characteristic<Peripheral>, timeout: TimeInterval = .gattDefaultTimeout) throws -> Data {
        
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        NSLog("\(type(of: self)) \(#function) controller isEnabled")
        
        // store semaphore
        let semaphore = Semaphore(timeout: timeout)
        accessQueue.sync { [unowned self] in self.internalState.readCharacteristic.semaphore = semaphore }
        defer { accessQueue.sync { [unowned self] in self.internalState.readCharacteristic.semaphore = nil } }
        
        try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[characteristic.peripheral]
                else { throw CentralError.disconnected }
            
            NSLog("\(type(of: self)) \(#function) cache")
            
            guard let gattCharacteristic = cache.characteristics.values[characteristic.identifier]
                else { throw AndroidCentralError.characteristicNotFound }
            
            NSLog("\(type(of: self)) \(#function) cache")
            
            guard cache.gatt.readCharacteristic(characteristic: gattCharacteristic)
                else { throw AndroidCentralError.binderFailure }
            
            NSLog("\(type(of: self)) \(#function) read success: true")
        }
        
        NSLog("\(type(of: self)) \(#function) start waiting")
        // throw async error
        do { try semaphore.wait() }
        
        NSLog("\(type(of: self)) \(#function) finish waiting")
        
        // get values from internal state
        return try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[characteristic.peripheral]
                else { throw CentralError.unknownPeripheral }
            
            NSLog("\(type(of: self)) \(#function) cache")
            
            guard let readCharacteristic = cache.readCharacteristic
                else { throw CentralError.invalidAttribute(characteristic.uuid) }
            
            NSLog("\(type(of: self)) \(#function) readCharacteristic = \(readCharacteristic.getProperties())")

            if let value = readCharacteristic.getValue() {
                
                NSLog("\(type(of: self)) \(#function) characteristic value: \(value)")
                
                return Data(unsafeBitCast(value, to: [UInt8].self))
            } else {
                NSLog("\(type(of: self)) \(#function) characteristic no value")
                return Data()
            }
        }
    }
    
    public func writeValue(_ data: Data, for characteristic: Characteristic<Peripheral>, withResponse: Bool = true, timeout: TimeInterval = .gattDefaultTimeout) throws {
        
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        // store semaphore
        let semaphore = Semaphore(timeout: timeout)
        accessQueue.sync { [unowned self] in self.internalState.writeCharacteristic.semaphore = semaphore }
        defer { accessQueue.sync { [unowned self] in self.internalState.writeCharacteristic.semaphore = nil } }
        
        try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[characteristic.peripheral]
                else { throw CentralError.disconnected }
            
            guard let gattCharacteristic = cache.characteristics.values[characteristic.identifier]
                else { throw AndroidCentralError.characteristicNotFound }
            
            let dataArray = [UInt8](data)
            
            let _ = gattCharacteristic.setValue(value: unsafeBitCast(dataArray, to: [Int8].self))
            
            guard cache.gatt.writeCharacteristic(characteristic: gattCharacteristic)
                else { throw AndroidCentralError.binderFailure }
        }
        
        // throw async error
        do { try semaphore.wait() }
    
    }
    
    public func notify(_ notification: ((Data) -> ())?, for characteristic: Characteristic<Peripheral>, timeout: TimeInterval = .gattDefaultTimeout) throws {
        NSLog("\(type(of: self)) \(#function)")
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        let enable = notification != nil
        
        // store semaphore
        let semaphore = Semaphore(timeout: timeout)
        accessQueue.sync { [unowned self] in self.internalState.notify.semaphore = semaphore }
        defer { accessQueue.sync { [unowned self] in self.internalState.notify.semaphore = nil } }
        
        try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[characteristic.peripheral]
                else { throw CentralError.disconnected }
            
            guard let gattCharacteristic = cache.characteristics.values[characteristic.identifier]
                else { throw AndroidCentralError.characteristicNotFound }
            
            guard cache.gatt.setCharacteristicNotification(characteristic: gattCharacteristic, enable: enable) else {
                throw AndroidCentralError.binderFailure
            }
            
            ///0x2902
            let uuid = java_util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
            //let uuid = java_util.UUID.nameUUIDFromBytes([0x00, 0x10, 0x10, 0x01, 0x00, 0x00, 0x00, 0x10])
            
            guard let descriptor = gattCharacteristic.getDescriptor(uuid: uuid!) else {
                NSLog("ERROR: descriptor doesnt exits")
                throw AndroidCentralError.binderFailure
            }
            
            let valueEnableNotification : [Int8] = enable ? [0x01, 0x00] : [0x00, 0x00]
            
            let wasLocallyStored = descriptor.setValue(valueEnableNotification)
            
            guard cache.gatt.writeDescriptor(descriptor: descriptor) else {
                throw AndroidCentralError.binderFailure
            }
            
            NSLog("\(type(of: self)) \(#function)  \(enable ? "start": "stop") : true , locallyStored: \(wasLocallyStored)")
        }
        
        
    }
    
    public func maximumTransmissionUnit(for peripheral: Peripheral) throws -> ATTMaximumTransmissionUnit {
        
        guard hostController.isEnabled()
            else { throw AndroidCentralError.bluetoothDisabled }
        
        // access the cached value
        return try accessQueue.sync { [unowned self] in
            
            guard let cache = self.internalState.cache[peripheral]
                else { throw CentralError.disconnected }
            
            return cache.maximumTransmissionUnit
        }
    }
    
    //MARK: Android
    
    private class ScanCallback: Android.Bluetooth.LE.ScanCallback {
        
        weak var central: AndroidCentral?
        
        public required init(javaObject: jobject?) {
            super.init(javaObject: javaObject)
        }
        
        convenience init() {
            
            self.init(javaObject: nil)
            bindNewJavaObject()
        }
        
        public override func onScanResult(callbackType: Android.Bluetooth.LE.ScanCallbackType,
                                          result: Android.Bluetooth.LE.ScanResult) {
            
            central?.log?("\(type(of: self)) \(#function) name: \(result.device.getName() ?? "") address: \(result.device.address)")
            
            let peripheral = Peripheral(identifier: result.device.address)
            
            let record = result.scanRecord
            
            guard let advertisement = AdvertisementData(android: Data(record.bytes))
                else { central?.log?("\(#function) Could not initialize advertisement data from \(record.bytes)"); return }
            
            let isConnectable: Bool
            
            if AndroidBuild.Version.Sdk.sdkInt.rawValue >= AndroidBuild.VersionCodes.O {
                
                isConnectable = result.isConnectable
                
            } else {
                
                isConnectable = true // FIXME: ??
            }
            
            let scanData = ScanData(peripheral: peripheral,
                                    date: Date(),
                                    rssi: Double(result.rssi),
                                    advertisementData: advertisement,
                                    isConnectable: isConnectable)
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                central.internalState.scan.foundDevice?(scanData)
                central.internalState.scan.peripherals[peripheral] = InternalState.Scan.Device(scanData: scanData,
                                                                                               scanResult: result)
            }
        }
        
        public override func onBatchScanResults(results: [Android.Bluetooth.LE.ScanResult]) {
            
            central?.log?("\(type(of: self)): \(#function)")
        }
        
        public override func onScanFailed(error: AndroidBluetoothLowEnergyScanCallback.Error) {
 
            central?.log?("\(type(of: self)): \(#function)")
        }
    }
    
    public class GattCallback: Android.Bluetooth.GattCallback {
        
        private weak var central: AndroidCentral?
        
        convenience init(central: AndroidCentral) {
            self.init(javaObject: nil)
            bindNewJavaObject()
            
            self.central = central
        }
        
        public required init(javaObject: jobject?) {
            super.init(javaObject: javaObject)
        }
        
        public override func onConnectionStateChange(gatt: Android.Bluetooth.Gatt,
                                            status: AndroidBluetoothGatt.Status,
                                            newState: AndroidBluetoothDevice.State) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
            central?.log?("Status: \(status) - newState = \(newState)")
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                
                switch (status, newState) {
                    
                case (.success, .connected):
                    
                    central.log?("GATT Connected")
                    
                    // if we are expecting a new connection
                    if central.internalState.connect.semaphore != nil {
                        
                        central.internalState.connect.semaphore?.stopWaiting()
                        central.internalState.connect.semaphore = nil
                    }
                    
                case (.success, .disconnected):
                    
                    central.log?("GATT Disconnected")
                    
                    break // nothing for now
                    
                default:
                    
                    central.log?("GATT Status Error")
                    
                    central.internalState.connect.semaphore?.stopWaiting(status) // throw `status` error
                }
            }
        }
        
        public override func onServicesDiscovered(gatt: Android.Bluetooth.Gatt,
                                                  status: AndroidBluetoothGatt.Status) {
            
            let peripheral = Peripheral(gatt)
            
            central?.log?("\(type(of: self)): \(#function)")
            
            central?.log?("\(peripheral) Status: \(status)")
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                
                guard status == .success
                    else { central.internalState.discoverServices.semaphore?.stopWaiting(status); return }
                
                central.internalState.cache[peripheral]?.update(gatt.services)
                
                // success
                central.internalState.discoverServices.semaphore?.stopWaiting()
                central.internalState.discoverServices.semaphore = nil
            }
        }
        
        public override func onCharacteristicChanged(gatt: Android.Bluetooth.Gatt, characteristic: Android.Bluetooth.GattCharacteristic) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
        }
        
        public override func onCharacteristicRead(gatt: Android.Bluetooth.Gatt, characteristic: Android.Bluetooth.GattCharacteristic, status: AndroidBluetoothGatt.Status) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
            let peripheral = Peripheral(gatt)
            
            central?.log?("\(type(of: self)): \(#function) got peripheral")
            
            central?.log?("\(peripheral) Status: \(status)")
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                
                central.log?("\(type(of: self)): \(#function) got centrar again")
                
                guard status == .success
                    else { central.internalState.readCharacteristic.semaphore?.stopWaiting(status); return }
                
                central.log?("\(type(of: self)): \(#function) status: \(status)")
                
                central.internalState.cache[peripheral]?.update(characteristic)
                
                central.log?("\(type(of: self)): \(#function) characteristic was updated on cache")
                
                // success
                central.internalState.readCharacteristic.semaphore?.stopWaiting()
            }
        }
        
        public override func onCharacteristicWrite(gatt: Android.Bluetooth.Gatt, characteristic: Android.Bluetooth.GattCharacteristic, status: AndroidBluetoothGatt.Status) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
            let peripheral = Peripheral(gatt)
            
            central?.log?("\(type(of: self)): \(#function)")
            
            central?.log?("\(peripheral) Status: \(status)")
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                
                guard status == .success
                    else { central.internalState.writeCharacteristic.semaphore?.stopWaiting(status); return }
                
                // success
                central.internalState.writeCharacteristic.semaphore?.stopWaiting()
                central.internalState.writeCharacteristic.semaphore = nil
            }
        }
        
        public override func onDescriptorRead(gatt: Android.Bluetooth.Gatt, descriptor: Android.Bluetooth.GattDescriptor, status: AndroidBluetoothGatt.Status) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
        }
        
        public override func onDescriptorWrite(gatt: Android.Bluetooth.Gatt, descriptor: Android.Bluetooth.GattDescriptor, status: AndroidBluetoothGatt.Status) {
            
            central?.log?("\(type(of: self)): \(#function)")
            
        }
        
        public override func onMtuChanged(gatt: Android.Bluetooth.Gatt,
                                          mtu: Int,
                                          status: Android.Bluetooth.Gatt.Status) {
            
            central?.log?("\(type(of: self)): \(#function) Peripheral \(Peripheral(gatt)) MTU \(mtu) Status \(status)")
            
            let peripheral = Peripheral(gatt)
            
            central?.accessQueue.async { [weak self] in
                
                guard let central = self?.central
                    else { return }
                
                // get new MTU value
                guard let newMTU = ATTMaximumTransmissionUnit(rawValue: UInt16(mtu))
                    else { fatalError("Invalid MTU \(mtu)") }
                
                // cache new MTU value
                central.internalState.cache[peripheral]?.maximumTransmissionUnit = newMTU
            }
        }
        
        public override func onPhyRead(gatt: Android.Bluetooth.Gatt, txPhy: AndroidBluetoothGatt.TxPhy, rxPhy: AndroidBluetoothGatt.RxPhy, status: AndroidBluetoothGatt.Status) {
            
            NSLog("\(type(of: self)): \(#function)")
            
        }
        
        public override func onPhyUpdate(gatt: Android.Bluetooth.Gatt, txPhy: AndroidBluetoothGatt.TxPhy, rxPhy: AndroidBluetoothGatt.RxPhy, status: AndroidBluetoothGatt.Status) {
            
            NSLog("\(type(of: self)): \(#function)")
            
        }
        
        public override func onReadRemoteRssi(gatt: Android.Bluetooth.Gatt, rssi: Int, status: AndroidBluetoothGatt.Status) {
            NSLog("\(type(of: self)): \(#function)")
            
        }
        
        public override func onReliableWriteCompleted(gatt: Android.Bluetooth.Gatt, status: AndroidBluetoothGatt.Status) {
            NSLog("\(type(of: self)): \(#function)")
            
        }
    }
    
}

// MARK: - Supporting Types

public extension AndroidCentral {
    
    /// Android GATT Central options
    public struct Options {
        
        public let maximumTransmissionUnit: ATTMaximumTransmissionUnit
        
        public init(maximumTransmissionUnit: ATTMaximumTransmissionUnit = .default) {
            
            self.maximumTransmissionUnit = maximumTransmissionUnit
        }
    }
}

// MARK: - Private Supporting Types

internal extension AndroidCentral {
    
    struct InternalState {
        
        fileprivate init() { }
        
        var cache = [Peripheral: Cache]()
        
        var scan = Scan()
        
        struct Scan {
            
            var peripherals = [Peripheral: Device]()
            
            var foundDevice: ((ScanData<Peripheral, Advertisement>) -> ())?
            
            struct Device {
                
                let scanData: ScanData<Peripheral, AdvertisementData>
                
                let scanResult: Android.Bluetooth.LE.ScanResult
            }
        }
        
        var connect = Connect()
        
        struct Connect {
            
            var semaphore: Semaphore?
        }
        
        var discoverServices = DiscoverServices()
        
        struct DiscoverServices {
            
            var semaphore: Semaphore?
        }
        
        var discoverCharacteristics = DiscoverCharacteristics()
        
        struct DiscoverCharacteristics {
            
            var semaphore: Semaphore?
        }
        
        var readCharacteristic = ReadCharacteristic()
        
        struct ReadCharacteristic {
            
            var semaphore: Semaphore?
        }
        
        var writeCharacteristic = WriteCharacteristic()
        
        struct WriteCharacteristic {
            
            var semaphore: Semaphore?
        }
        
        var notify = Notify()
        
        struct Notify {
            
            var semaphore: Semaphore?
        }
    }
}

internal extension AndroidCentral {
    
    /// GATT cache for a connection or peripheral.
    final class Cache {
        
        fileprivate init(gatt: Android.Bluetooth.Gatt,
                         callback: GattCallback) {
            
            self.gatt = gatt
            self.gattCallback = callback
        }
        
        let gattCallback: GattCallback
        
        let gatt: Android.Bluetooth.Gatt
        
        fileprivate(set) var maximumTransmissionUnit: ATTMaximumTransmissionUnit = .default
        
        var services = Services()
        
        var characteristics = Characteristics()
        
        var readCharacteristic: Android.Bluetooth.GattCharacteristic?
        
        struct Characteristics {
            
            fileprivate(set) var values: [UInt: Android.Bluetooth.GattCharacteristic] = [:]
        }
        
        struct Services {
            
            fileprivate(set) var values: [UInt: Android.Bluetooth.GattService] = [:]
        }
        
        fileprivate func update(_ newValues: [Android.Bluetooth.GattService]) {
            
            services.values.removeAll()
            
            newValues.forEach {
                
                let identifier = UInt(bitPattern: $0.getUuid().toString().hashValue ^ $0.getInstanceId())
                services.values[identifier] = $0
            }
        }
        
        fileprivate func update(_ newValues: [Android.Bluetooth.GattCharacteristic], for service: Service<Peripheral>) {
            
            newValues.forEach {
                
                let identifier = UInt(bitPattern: $0.getUuid().toString().hashValue ^ $0.getInstanceId())
                characteristics.values[identifier] = $0
            }
        }
        
        fileprivate func update(_ newValue: Android.Bluetooth.GattCharacteristic) {
            
            readCharacteristic = newValue
        }
    }
}

internal extension AndroidCentral {
    
    final class Semaphore {
        
        let semaphore: DispatchSemaphore
        let timeout: TimeInterval
        var error: Swift.Error?
        
        init(timeout: TimeInterval) {
            
            self.timeout = timeout
            self.semaphore = DispatchSemaphore(value: 0)
            self.error = nil
        }
        
        func wait() throws {
            
            let dispatchTime: DispatchTime = .now() + timeout
            
            let success = semaphore.wait(timeout: dispatchTime) == .success
            
            if let error = self.error {
                
                throw error
            }
            
            guard success else { throw CentralError.timeout }
        }
        
        func stopWaiting(_ error: Swift.Error? = nil) {
            
            // store signal
            self.error = error
            
            // stop blocking
            semaphore.signal()
        }
    }
}

// MARK: - Extentions

fileprivate extension Peripheral {
    
    init(_ device: AndroidBluetoothDevice) {
        
        self.init(identifier: device.address)
    }
    
    init(_ gatt: AndroidBluetoothGatt) {
        
        self.init(gatt.getDevice())
    }
}

internal extension BluetoothUUID {
    
    init(android javaUUID: java_util.UUID) {
        
        let uuid = UUID(uuidString: javaUUID.toString())!
        
        if let value = UInt16(bluetooth: uuid) {
            
            self = .bit16(value)
            
        } else {
            
            self = .bit128(UInt128(uuid: uuid))
        }
    }
}

//#endif
