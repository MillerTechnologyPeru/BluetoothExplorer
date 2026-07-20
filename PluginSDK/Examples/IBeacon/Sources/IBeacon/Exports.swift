//
//  Exports.swift
//  IBeacon
//
//  ABI export shims. These live in the plugin's own module because `@_expose(wasm)` symbols are
//  dropped when they come from a dependency module (swiftlang/swift#77812). Copied unchanged from
//  the SDK template, with only the capability shims this plugin implements.
//

import BLEPluginSDK

@_expose(wasm, "bleplug_abi_1")
@_cdecl("bleplug_abi_1")
func bleplugABIMarker() {}

@_expose(wasm, "bleplug_alloc")
@_cdecl("bleplug_alloc")
func bleplugAlloc(_ size: UInt32) -> UInt32 {
    PluginRuntime.allocate(size)
}

@_expose(wasm, "bleplug_free")
@_cdecl("bleplug_free")
func bleplugFree(_ pointer: UInt32, _ size: UInt32) {
    PluginRuntime.deallocate(pointer)
}

@_expose(wasm, "bleplug_parse_manufacturer")
@_cdecl("bleplug_parse_manufacturer")
func bleplugParseManufacturer(_ pointer: UInt32, _ length: UInt32) -> UInt64 {
    PluginRuntime.handle(pointer: pointer, length: length, parse: parseManufacturerData)
}
