//
//  PluginResourceLimiter.swift
//  BluetoothExplorerPluginEngine
//

import Foundation
import WasmKit

/// Caps a plugin's guest linear-memory and table growth. Instances are confined to their
/// runner's serial queue, so this type is only ever touched from that queue.
final class PluginResourceLimiter: ResourceLimiter {

    let maxMemoryBytes: Int
    let maxTableElements: Int

    init(maxMemoryBytes: Int, maxTableElements: Int = 10_000) {
        self.maxMemoryBytes = maxMemoryBytes
        self.maxTableElements = maxTableElements
    }

    func limitMemoryGrowth(to desired: Int) throws -> Bool {
        desired <= maxMemoryBytes
    }

    func limitTableGrowth(to desired: Int) throws -> Bool {
        desired <= maxTableElements
    }
}
