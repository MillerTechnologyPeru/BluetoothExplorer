//
//  DarwinAdvertisementData.swift
//  GATT
//
//  Created by Alsey Coleman Miller on 7/15/18.
//

import Foundation
import Bluetooth
import GATT

#if os(macOS) || os(iOS) || os(tvOS) || (os(watchOS) && swift(>=3.2))

import CoreBluetooth

/// CoreBluetooth Adverisement Data
public struct DarwinAdvertisementData: AdvertisementDataProtocol {
    
    // MARK: - Properties
    
    internal let data: [String: NSObject]
    
    // MARK: - Initialization
    
    internal init(_ coreBluetooth: [String: Any]) {
        
        guard let data = coreBluetooth as? [String: NSObject]
            else { fatalError("Invalid dictionary \(coreBluetooth)") }
        
        self.data = data
    }
}
    
// MARK: - Equatable

extension DarwinAdvertisementData: Equatable {
    
    public static func == (lhs: DarwinAdvertisementData, rhs: DarwinAdvertisementData) -> Bool {
        
        return lhs.data == rhs.data
    }
}
    
// MARK: - AdvertisementDataProtocol
    
public extension DarwinAdvertisementData {
    
    /// The local name of a peripheral.
    public var localName: String? {
        
        return data[CBAdvertisementDataLocalNameKey] as? String
    }
    
    /// The Manufacturer data of a peripheral.
    public var manufacturerData: GAPManufacturerSpecificData? {
        
        guard let manufacturerDataBytes = data[CBAdvertisementDataManufacturerDataKey] as? Data,
            let manufacturerData = GAPManufacturerSpecificData(data: manufacturerDataBytes)
            else { return nil }
        
        return manufacturerData
    }
    
    /// Service-specific advertisement data.
    public var serviceData: [BluetoothUUID: Data]? {
        
        guard let coreBluetoothServiceData = data[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
            else { return nil }
        
        var serviceData = [BluetoothUUID: Data](minimumCapacity: coreBluetoothServiceData.count)
            
        for (key, value) in coreBluetoothServiceData {
                
            let uuid = BluetoothUUID(coreBluetooth: key)
                
            serviceData[uuid] = value
        }
            
        return serviceData
    }
    
    /// An array of service UUIDs
    public var serviceUUIDs: [BluetoothUUID]? {
        
        return (data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { BluetoothUUID(coreBluetooth: $0) }
    }
    
    /// This value is available if the broadcaster (peripheral) provides its Tx power level in its advertising packet.
    /// Using the RSSI value and the Tx power level, it is possible to calculate path loss.
    public var txPowerLevel: Double? {
        
        return (data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.doubleValue
    }
    
    /// An array of one or more `BluetoothUUID`, representing Service UUIDs.
    public var solicitedServiceUUIDs: [BluetoothUUID]? {
        
        return (data[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID])?.map { BluetoothUUID(coreBluetooth: $0) }
    }
    
    // MARK: - CoreBluetooth Specific Values
    
    /// A Boolean value that indicates whether the advertising event type is connectable.
    internal var isConnectable: Bool? {
        
        return (data[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
    }
    
    /// An array of one or more `BluetoothUUID`, representing Service UUIDs that were found
    /// in the “overflow” area of the advertisement data.
    public var overflowServiceUUIDs: [BluetoothUUID]? {
        
        return (data[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID])?.map { BluetoothUUID(coreBluetooth: $0) }
    }
}

#endif
