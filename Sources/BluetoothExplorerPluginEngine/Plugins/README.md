# Bundled Plugins

Each bundled plugin is a `<name>.wasm` module paired with a `<name>.bleplugin.json` manifest.
These are copied verbatim into the app bundle (and the Android APK) and loaded at launch by
`PluginManager.loadBundledPlugins()`.

The modules here are build artifacts. Their source lives in `PluginSDK/Examples/`, written in
Embedded Swift against `BLEPluginSDK`. To rebuild and reinstall one:

```sh
cd PluginSDK/Examples/GATTTime
make install     # builds for wasm32, runs wasm-opt -Oz, copies here, refreshes the manifest sha256
```

## GATT characteristics

All 71 characteristic types in `BluetoothGATT` are covered, ported to Embedded Swift and grouped by
service family. Grouping rather than one-plugin-per-characteristic keeps the bundle to ~1.5 MB
instead of ~6.7 MB, since each module carries its own copy of the Embedded Swift runtime; routing is
still per-UUID from the manifest, so the app behaves identically either way.

| Plugin | Characteristics |
|---|---|
| `gatt-time` | 15 — Date Time, Current Time, DST/time zone, time source and accuracy, update state |
| `gatt-alert-notification` | 9 — alert level/status/category, new and unread alerts, control point |
| `gatt-indoor-positioning` | 9 — latitude, longitude, local coordinates, floor, altitude, uncertainty |
| `gatt-device-information` | 8 — manufacturer/model/serial, firmware/hardware/software revision, System ID, PnP ID |
| `gatt-generic-service` | 7 — service changed, scan refresh/interval, address resolution, client features, database hash, security levels |
| `gatt-user-data` | 6 — aerobic/anaerobic heart rate limits, thresholds, age |
| `gatt-object-transfer` | 4 — object name, type, size, ID |
| `gatt-body-fitness` | 3 — body sensor location, body composition, cross trainer data |
| `gatt-hid` | 3 — boot keyboard input/output, boot mouse input |
| `gatt-misc` | 3 — barometric pressure trend, CGM session run time, encrypted data key material |
| `gatt-battery` | 2 — battery level, battery energy status |
| `gatt-blood-pressure` | 2 — blood pressure measurement and feature |

`ibeacon.wasm` additionally parses Apple iBeacon advertisements (manufacturer data, company 0x004C).

## Validation

`Tests/BluetoothExplorerPluginEngineTests/GATTPluginTests.swift` runs every module under the WasmKit
interpreter and checks that manifests declare exactly these 71 UUIDs with no duplicates, that each
declared UUID actually decodes, that plugins decline UUIDs they do not declare, that no module traps
on a corpus of malformed payloads, and — for the 35 characteristics whose BluetoothGATT parsers are
bounds-safe — that plugin and library agree on exactly which values are valid.

See `Documentation/PluginABI.md` for the ABI and `PluginSDK/README.md` for authoring.
