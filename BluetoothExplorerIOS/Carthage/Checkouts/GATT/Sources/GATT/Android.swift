//
//  Android.swift
//  GATT
//
//  Created by Alsey Coleman Miller on 8/15/18.
//

import Foundation
import Bluetooth

public extension AdvertisementData {
    
    /// Initialize with raw bytes of Android scan record.
    ///
    /// - SeeAlso: [Android ScanRecord](https://developer.android.com/reference/android/bluetooth/le/ScanRecord)
    init?(android rawBytes: Data) {
        
        switch rawBytes.count {
            
        case 31:
            
            guard let advertisement = LowEnergyAdvertisingData(android: rawBytes)
                else { return nil }
            
            self.init(advertisement: advertisement)
            
        case 62:
            
            guard let advertisement = LowEnergyAdvertisingData(android: Data(rawBytes.subdata(in: 0 ..< 31))),
                let scanResponse = LowEnergyAdvertisingData(android: Data(rawBytes.subdata(in: 31 ..< 62)))
                else { return nil }
            
            self.init(advertisement: advertisement, scanResponse: scanResponse)
            
        default:
            
            return nil
        }
    }
}

private extension LowEnergyAdvertisingData {
    
    init?(android data: Data) {
        
        // always 31 (passive scan) or 62 bytes (active scan)
        guard data.count == 31
            else { return nil }
        
        self.init(data: data)
    }
}
