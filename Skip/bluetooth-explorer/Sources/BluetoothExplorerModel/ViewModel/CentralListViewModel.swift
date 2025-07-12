//
//  CentralListViewModel.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 7/11/25.
//

import Foundation
import Bluetooth
import GATT
import SkipFuse

@MainActor
@Observable
public final class CentralListViewModel {
    
    let store: Store
    
    var scanToggleTask: Task<Void, Never>?
    
    public init(store: Store) {
        self.store = store
    }
    
    public var scanResults: [ScanResult] {
        store.scanResults
            .values
            .lazy
            .sorted(by: { $0.id.description < $1.id.description })
            .sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
            .sorted(by: { $0.name != nil && $1.name == nil })
            .sorted(by: { $0.beacon != nil && $1.beacon == nil })
            .map { ScanResult($0) }
    }
    
    public var isEnabled: Bool {
        store.isEnabled
    }
    
    public var isScanning: Bool {
        store.isScanning
    }
    
    public var canToggleScan: Bool {
        scanToggleTask == nil && store.isEnabled
    }
    
    public func scanToggle() {
        scanToggleTask = Task {
            defer { scanToggleTask = nil }
            if store.isScanning {
                await store.stopScan()
            } else {
                do {
                    try await store.scan()
                }
                catch {
                    store.log(error: error)
                }
            }
        }
    }
    
    public struct ScanResult: Equatable, Hashable, Sendable, Identifiable {
        
        @MainActor
        static let listFormatter = ListFormatter()
        
        typealias ScanData = ScanDataCache<NativeCentral.Peripheral, NativeCentral.Advertisement>
        
        let scanData: ScanData
        
        init(_ scanData: ScanData) {
            self.scanData = scanData
        }
        
        public var id: String {
            scanData.id.description
        }
        
        public var name: String {
            scanData.name ?? (beacon != nil ? "iBeacon" : "Unknown")
        }
        
        public var company: String? {
            scanData.manufacturerData?.companyIdentifier.name
        }
        
        @MainActor
        public var services: String? {
            let services = scanData.serviceUUIDs
                .sorted(by: { $0.description < $1.description })
                .map { $0.metadata?.name ?? $0.rawValue }
            guard services.isEmpty == false
                else { return nil }
            return Self.listFormatter
                .string(from: services)
                .map { "Services: " + $0 }
        }
        
        public var beacon: CentralListViewModel.Beacon? {
            scanData.beacon.flatMap(Beacon.init)
        }
    }
    
    public struct Beacon: Equatable, Hashable, Sendable {
        
        let beacon: AppleBeacon
        
        init(_ beacon: AppleBeacon) {
            self.beacon = beacon
        }
        
        public var uuid: String {
            beacon.uuid.uuidString
        }
        
        public var major: String {
            "Major: 0x\(beacon.major.toHexadecimal())"
        }
        
        public var minor: String {
            "Minor: 0x\(beacon.minor.toHexadecimal())"
        }
        
        public var rssi: String {
            "RSSI: \(beacon.rssi)"
        }
    }
}
