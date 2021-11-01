//
//  Store.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 6/9/19.
//  Copyright © 2019 Alsey Coleman Miller. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Bluetooth
import GATT
import DarwinGATT

@MainActor
final class Store: ObservableObject {
    
    typealias Central = AsyncDarwinCentral
    
    // MARK: - Properties
    
    @Published
    var scanResults = [Central.Peripheral: ScanData<Central.Peripheral, Central.Advertisement>]()
    
    @Published
    var isScanning = false
    
    private let central: Central
    
    // MARK: - Initialization
    
    init(central: Central) {
        self.central = central
    }
    
    static let shared = Store(central: .shared)
    
    // MARK: - Methods
    
    func scan() async throws {
        isScanning = true
        scanResults.removeAll(keepingCapacity: true)
        let stream = central.scan(filterDuplicates: true)
        for try await scanData in stream {
            scanResults[scanData.peripheral] = scanData
        }
    }
    
    func stopScan() async {
        isScanning = false
        await central.stopScan()
    }
}
