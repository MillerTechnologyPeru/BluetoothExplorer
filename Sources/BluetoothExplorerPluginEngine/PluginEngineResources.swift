//
//  PluginEngineResources.swift
//  BluetoothExplorerPluginEngine
//

import Foundation

/// Access to resources bundled with the plugin engine (the built-in `.wasm` plugins).
public enum PluginEngineResources {

    /// The engine's resource bundle, containing the `Plugins/` directory.
    public static var bundle: Bundle { .module }
}
