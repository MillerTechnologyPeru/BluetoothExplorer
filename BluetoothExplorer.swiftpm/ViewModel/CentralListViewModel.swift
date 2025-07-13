//
//  CentralListViewModel.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 7/11/25.
//

import Foundation
import Bluetooth
import GATT
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

@MainActor
public final class CentralListViewModel: ObservableObject {
        
    let store: Store
    
    @Published
    var scanToggleTask: Task<Void, Never>?
    
    private var storeObserver: AnyCancellable?
    
    public init(store: Store) {
        self.store = store
        observeStore()
    }
    
    private func observeStore() {
        // observe store
        self.storeObserver = store.objectWillChange.sink(receiveValue: { [weak self] in
            self?.objectWillChange.send()
        })
    }
    
    var state: State {
        State(
            .init(
                store: store,
                didToggle: scanToggleTask != nil
            )
        )
    }
    
    public var scanResults: [ScanResult] {
        state.scanResults
    }
    
    public var isEnabled: Bool {
        state.isEnabled
    }
    
    public var isScanning: Bool {
        state.isScanning
    }
    
    public var canToggleScan: Bool {
        state.canToggleScan
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
}

public extension CentralListViewModel {
    
    struct State: Sendable {
        
        let input: Input
        
        init(_ input: Input) {
            self.input = input
        }
        
        public var scanResults: [ScanResult] {
            input.scanResults
                .values
                .lazy
                .sorted(by: { $0.id.description < $1.id.description })
                .sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
                .sorted(by: { $0.name != nil && $1.name == nil })
                .sorted(by: { $0.beacon != nil && $1.beacon == nil })
                .map { ScanResult($0) }
        }
        
        public var isEnabled: Bool {
            input.isEnabled
        }
        
        public var isScanning: Bool {
            input.isScanning
        }
        
        public var canToggleScan: Bool {
            input.didToggle == false && input.isEnabled
        }
    }
}

public extension CentralListViewModel.State {
    
    struct Input: Sendable {
        
        let scanResults: [Store.Peripheral: Store.ScanResult]
        
        let isEnabled: Bool
        
        let isScanning: Bool
        
        let didToggle: Bool
        
        init(scanResults: [Store.Peripheral : Store.ScanResult], isEnabled: Bool, isScanning: Bool, didToggle: Bool) {
            self.scanResults = scanResults
            self.isEnabled = isEnabled
            self.isScanning = isScanning
            self.didToggle = didToggle
        }
        
        @MainActor
        init(store: Store, didToggle: Bool) {
            self.scanResults = store.scanResults
            self.isEnabled = store.isEnabled
            self.isScanning = store.isScanning
            self.didToggle = didToggle
        }
    }
}

public extension CentralListViewModel {
    
    struct ScanResult: Identifiable {
        
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
        
        public var services: String? {
            let services = scanData.serviceUUIDs
                .sorted(by: { $0.description < $1.description })
                .map { $0.metadata?.name ?? $0.rawValue }
            guard services.isEmpty == false
            else { return nil }
            return "Services: " + services.reduce("", { ($0.isEmpty ? "" : ", ") + $1 })
        }
        
        public var beacon: CentralListViewModel.Beacon? {
            scanData.beacon.flatMap(Beacon.init)
        }
    }
}

public extension CentralListViewModel {
    
    struct Beacon: Sendable {
        
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
