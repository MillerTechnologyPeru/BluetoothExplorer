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

final class Store: BindableObject {
    
    // MARK: - Initialization
    
    static let shared = Store()
    
    init(central: NativeCentral = .shared) {
        self.central = central
    }
    
    // MARK: - Properties
    
    let didChange = PassthroughSubject<Store, Never>()
    
    let central: NativeCentral
    
    var scanDuration: TimeInterval = 10.0
    
    var filterDuplicates: Bool = false
    
    private(set) var state: BluetoothState = .idle {
        didSet { didChange.send(self) }
    }
    
    // MARK: - Methods
    
    func scan() {
        
        self.state = .scanning
        
        
    }
}

enum BluetoothState {
    
    case idle
    case scanning
    case connecting
    case discoverServices
    case discoverCharacteristics
    case read
    case write
    case notificationState
}
