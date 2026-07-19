//
//  WasmParserPlugin.swift
//  BluetoothExplorerPluginEngine
//
//  A ParserPlugin backed by a WASM module. Loading validates the module against its manifest;
//  parsing delegates to the runner and decodes the CBOR output. Failures never propagate —
//  the caller falls back to other parsers or the raw hex view.
//

import Foundation
import Bluetooth

public struct WasmParserPlugin: ParserPlugin {

    public let id: PluginID
    public let name: String
    public let routingKeys: RoutingKeys

    private let runner: WasmPluginRunner

    /// Load and validate a WASM plugin from its manifest and module bytes.
    /// - Throws: `PluginError` if the manifest or module is invalid.
    public init(manifest: PluginManifest, moduleBytes: [UInt8], deadline: Duration = .milliseconds(50)) throws {
        try manifest.validate()

        self.id = manifest.id
        self.name = manifest.name
        self.routingKeys = RoutingKeys(
            companyIdentifiers: manifest.matches.companyIdentifiers,
            serviceDataUUIDs: manifest.serviceDataBluetoothUUIDs,
            characteristicUUIDs: manifest.characteristicBluetoothUUIDs,
            descriptorUUIDs: manifest.descriptorBluetoothUUIDs
        )

        let runner = WasmPluginRunner(manifest: manifest, moduleBytes: moduleBytes, deadline: deadline)
        try runner.validate()
        self.runner = runner
    }

    public var isQuarantined: Bool { runner.isQuarantined }

    public func parse(_ request: ParseRequest) async -> DecodedResult? {
        let outcome = await runner.invoke(request)
        switch outcome {
        case let .success(bytes?):
            return try? DecodedResult.decode(cbor: bytes, pluginID: id)
        case .success(nil), .failure:
            return nil
        }
    }
}
