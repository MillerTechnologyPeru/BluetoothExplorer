//
//  Metadata.swift
//  bluetooth-explorer
//
//  Created by Alsey Coleman Miller on 2/13/26.
//

import Foundation
import Bluetooth
import BluetoothMetadata

public extension Bluetooth.BluetoothUUID {

    /// Fetch the metadata for the UUID.
    var appMetadata: BluetoothMetadata.BluetoothUUID? {
        guard case let .bit16(rawValue) = self else {
            return nil
        }
        for file in files.values {
            if let metadata = file[rawValue] {
                return metadata
            }
        }
        return nil
    }
}

public extension Bluetooth.CompanyIdentifier {

    /// Bluetooth Company name.
    ///
    /// - SeeAlso: [Company Identifiers](https://www.bluetooth.com/specifications/assigned-numbers/company-identifiers)
    var appName: String? {
        return nil
    }
}

internal let files: [BluetoothMetadata.BluetoothUUID.Category: BluetoothMetadata.BluetoothUUID.File] = {
    return [:] // Implement
}()
