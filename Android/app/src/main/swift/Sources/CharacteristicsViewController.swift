//
//  CharacteristicsViewController.swift
//  BluetoothExplorerAndroid
//
//  Created by Marco Estrella on 9/18/18.
//

import Foundation
import Bluetooth
import GATT

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
#endif

/// Services
final class CharacteristicsViewController: UITableViewController {
    
    typealias NativeScanData = ScanData<NativeCentral.Peripheral, NativeCentral.Advertisement>
    
    //typealias NativeService = Service<NativeCentral.Advertisement>
    
    #if os(iOS)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}
