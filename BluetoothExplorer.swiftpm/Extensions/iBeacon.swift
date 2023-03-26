//
//  iBeacon.swift
//  
//
//  Created by Alsey Coleman Miller on 3/26/23.
//

import Foundation
import Bluetooth
import GATT

internal extension AppleBeacon {
    
    init?(manufacturerData: GATT.ManufacturerSpecificData) {
        
        let data = manufacturerData.additionalData
        
        guard manufacturerData.companyIdentifier == type(of: self).companyIdentifier,
            data.count > 2
            else { return nil }
        
        let dataType = data[0]
        
        guard dataType == type(of: self).appleDataType
            else { return nil }
        
        let length = data[1]
        
        guard length == type(of: self).length,
            data.count == type(of: self).additionalDataLength
            else { return nil }
        
        let uuid = UUID(UInt128(bigEndian: UInt128(data: data.subdataNoCopy(in: 2 ..< 18))!))
        let major = UInt16(bigEndian: UInt16(bytes: (data[18], data[19])))
        let minor = UInt16(bigEndian: UInt16(bytes: (data[20], data[21])))
        let rssi = Int8(bitPattern: data[22])
        
        self.init(uuid: uuid, major: major, minor: minor, rssi: rssi)
    }
}

internal extension AppleBeacon {
        
    /// Apple iBeacon data type.
    static var appleDataType: UInt8 { return 0x02 } // iBeacon
    
    /// The length of the TLV encoded data.
    static var length: UInt8 { return 0x15 } // length: 21 = 16 byte UUID + 2 bytes major + 2 bytes minor + 1 byte RSSI
    
    static var additionalDataLength: Int { return Int(length) + 2 }
}

internal extension GATT.AdvertisementData {
    
    var beacon: AppleBeacon? {
        manufacturerData.flatMap { AppleBeacon(manufacturerData: $0) }
    }
}
