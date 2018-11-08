//
//  AndroidAdvertisement.swift
//  BluetoothExplorerAndroid
//
//  Created by Alsey Coleman Miller on 11/7/18.
//

import Foundation
import Bluetooth
import GATT

/// Android's BLE Advertisement data
public struct AndroidLowEnergyAdvertisementData: Equatable {
    
    public let data: Data
    
    internal init(data: Data) {
        self.data = data
    }
}

extension AndroidLowEnergyAdvertisementData: AdvertisementDataProtocol {
    
    /// The local name of a peripheral.
    public var localName: String? {
        
        let types: [GAPData.Type] = [
            GAPCompleteLocalName.self,
            GAPShortLocalName.self
        ]
        
        guard let decoded = try? GAPDataDecoder.decode(data, types: types, ignoreUnknownType: true)
            else { return nil }
        
        guard let name = decoded.compactMap({ $0 as? GAPCompleteLocalName }).first?.name
            ?? decoded.compactMap({ $0 as? GAPShortLocalName }).first?.name
            else { return nil }
        
        return name
    }
    
    /// The Manufacturer data of a peripheral.
    public var manufacturerData: GAPManufacturerSpecificData? {
        
        guard let value = (try? GAPDataDecoder.decode(data, types: [GAPManufacturerSpecificData.self], ignoreUnknownType: true))?.compactMap({ $0 as? GAPManufacturerSpecificData }).first
            else { return nil }
        
        return value
    }
    
    /// Service-specific advertisement data.
    public var serviceData: [BluetoothUUID: Data]? {
        
        let types: [GAPData.Type] = [
            GAPServiceData16BitUUID.self,
            GAPServiceData32BitUUID.self,
            GAPServiceData128BitUUID.self
        ]
        
        guard let decoded = try? GAPDataDecoder.decode(data, types: types, ignoreUnknownType: true),
            decoded.isEmpty == false
            else { return nil }
        
        var serviceData = [BluetoothUUID: Data](minimumCapacity: decoded.count)
        
        decoded.compactMap { $0 as? GAPServiceData16BitUUID }
            .forEach { serviceData[.bit16($0.uuid)] = $0.serviceData }
        
        decoded.compactMap { $0 as? GAPServiceData32BitUUID }
            .forEach { serviceData[.bit32($0.uuid)] = $0.serviceData }
        
        decoded.compactMap { $0 as? GAPServiceData128BitUUID }
            .forEach { serviceData[.bit128(UInt128(uuid: $0.uuid))] = $0.serviceData }
        
        return serviceData
    }
    
    /// An array of service UUIDs
    public var serviceUUIDs: [BluetoothUUID]? {
        
        let types: [GAPData.Type] = [
            GAPCompleteListOf16BitServiceClassUUIDs.self,
            GAPIncompleteListOf16BitServiceClassUUIDs.self,
            GAPCompleteListOf32BitServiceClassUUIDs.self,
            GAPIncompleteListOf32BitServiceClassUUIDs.self,
            GAPCompleteListOf128BitServiceClassUUIDs.self,
            GAPIncompleteListOf128BitServiceClassUUIDs.self
        ]
        
        guard let decoded = try? GAPDataDecoder.decode(data, types: types, ignoreUnknownType: true),
            decoded.isEmpty == false
            else { return nil }
        
        var uuids = [BluetoothUUID]()
        uuids.reserveCapacity(decoded.count)
        
        uuids += decoded
            .compactMap { $0 as? GAPCompleteListOf16BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID.bit16($0) } })
        
        uuids += decoded
            .compactMap { $0 as? GAPIncompleteListOf16BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID.bit16($0) } })
        
        uuids += decoded
            .compactMap { $0 as? GAPCompleteListOf32BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID.bit32($0) } })
        
        uuids += decoded
            .compactMap { $0 as? GAPIncompleteListOf32BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID.bit32($0) } })
        
        uuids += decoded
            .compactMap { $0 as? GAPCompleteListOf128BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID(uuid: $0) } })
        
        uuids += decoded
            .compactMap { $0 as? GAPIncompleteListOf128BitServiceClassUUIDs }
            .reduce([BluetoothUUID](), { $0 + $1.uuids.map { BluetoothUUID(uuid: $0) } })
        
        return uuids
    }
    
    /// This value is available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    public var txPowerLevel: Double? {
        
        guard let gapData = (try? GAPDataDecoder.decode(data, types: [GAPTxPowerLevel.self], ignoreUnknownType: true))?.first as? GAPTxPowerLevel else { return nil }
        
        return Double(gapData.powerLevel)
    }
    
    /// An array of one or more `BluetoothUUID`, representing Service UUIDs.
    public var solicitedServiceUUIDs: [BluetoothUUID]? {
        
        let types: [GAPData.Type] = [
            GAPListOf16BitServiceSolicitationUUIDs.self,
            GAPListOf32BitServiceSolicitationUUIDs.self,
            GAPListOf128BitServiceSolicitationUUIDs.self
        ]
        
        guard let decoded = try? GAPDataDecoder.decode(data, types: types, ignoreUnknownType: true),
            decoded.isEmpty == false
            else { return nil }
        
        var uuids = [BluetoothUUID]()
        uuids.reserveCapacity(decoded.count)
        
        decoded.compactMap { $0 as? GAPListOf16BitServiceSolicitationUUIDs }
            .forEach { $0.uuids.forEach { uuids.append(.bit16($0)) } }
        
        decoded.compactMap { $0 as? GAPListOf32BitServiceSolicitationUUIDs }
            .forEach { $0.uuids.forEach { uuids.append(.bit32($0)) } }
        
        decoded.compactMap { $0 as? GAPListOf128BitServiceSolicitationUUIDs }
            .forEach { $0.uuids.forEach { uuids.append(.bit128(UInt128(uuid: $0))) } }
        
        return uuids
    }
}
