# BLE Parser Plugin SDK (Embedded Swift)

Write BluetoothExplorer parser plugins in **Embedded Swift**, compiled to a small wasm32 module the
app loads at runtime. A plugin decodes one kind of Bluetooth payload — manufacturer data, service
data, a characteristic or a descriptor value — into labelled fields the app displays.

- `BLEPluginSDK/` — the guest SDK: envelope decoding, a payload cursor, and a CBOR field builder.
- `Examples/BatteryLevel/` — a complete plugin (GATT Battery Level, `0x2A19`) you can copy.
- `../Documentation/PluginABI.md` — the normative wire contract.

## Prerequisites

```sh
swift sdk list                 # need swift-<version>_wasm-embedded
brew install binaryen          # for wasm-opt
```

If the embedded SDK is missing, install the `wasm-embedded` Swift SDK artifact bundle matching your
toolchain with `swift sdk install <url>`.

## Writing a plugin

The only file you write is a pure function from `ParseInput` to `Fields?`. Return `nil` for input
your plugin does not recognize — that is not an error, the app simply falls back.

```swift
import BLEPluginSDK

func parseCharacteristic(_ input: ParseInput) -> Fields? {
    guard input.uuid?.assignedNumber16 == 0x2A19 else { return nil }
    var payload = input.payload
    guard let level = payload.readUInt8() else { return nil }

    var fields = Fields(summary: "Battery")
    fields.uint("level", label: "Battery Level", UInt64(level), unit: "%")
    return fields
}
```

`Exports.swift` in the example is boilerplate you copy unchanged — it declares the ABI exports and
forwards them to `PluginRuntime`. It lives in *your* module rather than the SDK because
`@_expose(wasm)` symbols are dropped when they come from a dependency module
(swiftlang/swift#77812). Delete the capability shims your plugin does not implement; the host only
invokes exports that are present.

### Reading the payload

`PayloadReader` is an allocation-free cursor: `readUInt8`, `readInt8`, `readUInt16BigEndian`,
`readUInt16LittleEndian`, `readUInt32LittleEndian`, `readUUID`, `readBytes(_:_:)`, plus `remaining`
and `remainingBytes(_:)`.

### Emitting fields

`Fields` builds the CBOR result incrementally: `uint`, `int`, `double`, `bool`, `string`
(compile-time literal), `text` (UTF-8 from the payload), `bytes` (rendered as hex by the app), and
`uuid`. Keys, labels and units are `StaticString` so they cost no allocation.

Note that CBOR does not carry signedness: a value written with `int` arrives on the host as an
unsigned value whenever it is non-negative. The host compares integers numerically, so this does
not affect correctness or display — but do not expect the signed/unsigned distinction to survive
the boundary.

## Building

```sh
cd Examples/BatteryLevel
make            # build only
make install    # build, wasm-opt -Oz, copy into the app, refresh the manifest sha256
```

`make install` writes the module into
`Sources/BluetoothExplorerPluginEngine/Plugins/` and updates the manifest hash, so the app picks it
up on next launch. Expect roughly 90–110 KB per plugin after `wasm-opt -Oz`.

## The manifest

Every module needs a `<name>.bleplugin.json` sidecar telling the host what to route to it. The host
never runs a plugin for data it did not declare:

```json
{
  "manifestVersion": 1,
  "id": "org.example.plugin.battery-level",
  "name": "Battery Level",
  "version": "1.0.0",
  "abi": 1,
  "module": "battery-level.wasm",
  "sha256": "<filled in by make install>",
  "matches": { "characteristicUUIDs": ["2A19"] },
  "limits": { "maxMemoryPages": 16, "maxOutputBytes": 256 }
}
```

## What plugins can and cannot do

Plugins are pure decoders. The host runs them under a WebAssembly interpreter with:

- no filesystem, network, environment or clock access — the only host capability provided is
  randomness (`random_get`), which the Embedded Swift runtime requires;
- a linear-memory cap from `limits.maxMemoryPages`;
- a wall-clock deadline per call — a plugin that hangs is quarantined for the session;
- output validated against a strict CBOR subset and `limits.maxOutputBytes`.

Your parse function must be a **pure function of its input**: the host may cache results for
identical payloads and may recycle your instance between calls.
