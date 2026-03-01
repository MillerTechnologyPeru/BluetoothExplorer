//
//  PeripheralViewModel.swift
//  bluetooth-explorer
//
//  Created by Alsey Coleman Miller on 7/12/25.
//

import Foundation
import Observation
import Bluetooth
import GATT

@MainActor
@Observable
public final class PeripheralViewModel {
    
    let store: Store
    
    let peripheral: Store.Peripheral
        
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
    
    var title: String {
        store.scanResults[peripheral]?.name ?? "Device"
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var services: [Store.Service] {
        store.services[peripheral] ?? []
    }
    
    var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    public func connect() {
        
    }
    
    public func reload() {
        
    }
}
