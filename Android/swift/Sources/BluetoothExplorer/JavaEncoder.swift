//
//  JavaEncoder.swift
//  
//
//  Created by Alsey Coleman Miller on 11/30/22.
//

import Foundation
import JavaCoder

extension JavaEncoder {
    
    static var bluetoothExplorer: JavaEncoder {
        JavaCoderCache.encoder
    }
}

extension JavaDecoder {
    
    static var bluetoothExplorer: JavaDecoder {
        JavaCoderCache.decoder
    }
}

private struct JavaCoderCache {
    static let package = "org.millertechnology.bluetoothexplorer.model"
    static let encoder = JavaEncoder(forPackage: package)
    static let decoder = JavaDecoder(forPackage: package)
}
