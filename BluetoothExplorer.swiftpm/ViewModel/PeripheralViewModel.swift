//
//  PeripheralViewModel.swift
//  bluetooth-explorer
//
//  Created by Alsey Coleman Miller on 7/12/25.
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
public final class PeripheralViewModel: ObservableObject {
    
    let store: Store
    
    let peripheral: Store.Peripheral
    
    private var storeObserver: AnyCancellable?
        
    init(store: Store, peripheral: Peripheral) {
        self.store = store
        self.peripheral = peripheral
    }
    
    public convenience init(store: Store, peripheral: String) {
        guard let peripheral = store.scanResults.first(where: { $0.key.description == peripheral })?.key else {
            fatalError("Invalid peripheral: \(peripheral)")
        }
        self.init(store: store, peripheral: peripheral)
    }
    
    private func observeStore() {
        // observe store
        self.storeObserver = store.objectWillChange.sink(receiveValue: { [weak self] in
            self?.objectWillChange.send()
        })
    }
    
    public var title: String {
        store.scanResults[peripheral]?.name ?? "Device"
    }
    
    public var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var services: [Store.Service] {
        store.services[peripheral] ?? []
    }
    
    public var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    public func connect() {
        
    }
    
    public func reload() {
        
    }
}
