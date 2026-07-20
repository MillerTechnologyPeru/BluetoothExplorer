# BLE Parser Plugin ABI v1 (normative)

A plugin is a WebAssembly module that decodes a BLE advertisement field or GATT attribute value into
structured fields. The host is `BluetoothExplorerPluginEngine`, running the module under the WasmKit
interpreter.

This document is normative. The host implementation lives in
`Sources/BluetoothExplorerPluginEngine/PluginABI.swift`; plugins are authored in Embedded Swift
against `PluginSDK/BLEPluginSDK`, with a complete example in `PluginSDK/Examples/BatteryLevel`.

## Module requirements

- **Target.** `wasm32-unknown-wasip1` built as a **reactor** (`-mexec-model=reactor`) — what the
  Embedded Swift SDK emits. Import-free core modules are also accepted.
- **Imports.** Only `wasi_snapshot_preview1` may be imported; any other import module is rejected at
  load. The host satisfies those imports with a minimal shim rather than a real WASI
  implementation: `random_get` fills guest memory with real random bytes (the Embedded Swift runtime
  requires it), and every other WASI function is stubbed to return success with zeroed results. A
  plugin therefore has no filesystem, network, environment or clock access, and cannot call back
  into the host.
- **No JIT / no threads required.** Pure computation only.

## Required exports

| Export | Signature | Purpose |
|---|---|---|
| `bleplug_abi_1` | `() -> ()` | Version marker. Never called; its presence declares ABI major 1. |
| `bleplug_alloc` | `(size: i32) -> i32` | Return a pointer to `size` writable bytes in linear memory, or `0` on failure. The guest owns all allocation. |
| `memory` | (exported linear memory) | The host reads and writes here. |

## Capability exports (optional; presence = capability)

| Export | Signature | Invoked for |
|---|---|---|
| `bleplug_parse_manufacturer` | `(ptr: i32, len: i32) -> i64` | Manufacturer-specific advertisement data |
| `bleplug_parse_service_data` | `(ptr: i32, len: i32) -> i64` | Service data advertisement fields |
| `bleplug_parse_characteristic` | `(ptr: i32, len: i32) -> i64` | GATT characteristic values |
| `bleplug_parse_descriptor` | `(ptr: i32, len: i32) -> i64` | GATT descriptor values |

Each declared match category in the manifest must have its corresponding export, or the plugin is
rejected at load.

## Optional exports

| Export | Signature | Purpose |
|---|---|---|
| `bleplug_free` | `(ptr: i32, size: i32) -> ()` | Called on the input and output buffers after the host copies them out. |
| `bleplug_reset` | `() -> ()` | Called after each parse to reset a per-call arena. |
| `_initialize` | `() -> ()` | wasip1 reactor init; called once after instantiation. |

## Call sequence

For each parse, the host:

1. Encodes the input envelope (below) into `n` bytes.
2. Calls `bleplug_alloc(n)` → `ptr` (non-zero).
3. Writes the envelope into `memory` at `ptr`.
4. Calls the capability export `(ptr, n)` → packed `i64`.
5. Interprets the result: `0` means "not mine / no result" (not an error). Otherwise the value is
   `(result_ptr << 32) | result_len`, and the host reads `result_len` bytes from `memory` at
   `result_ptr`.
6. Calls `bleplug_free` and `bleplug_reset` if exported.

The parse function must be a **pure function of the envelope**: the host may cache results for
identical inputs and may recycle the instance between calls.

## Input envelope

Little-endian scalars; the UUID is 16 RFC-4122 **big-endian** bytes.

```
offset size  field
0      1     envelope_version   (= 1)
1      1     kind               (1=manufacturer, 2=serviceData, 3=characteristic, 4=descriptor)
2      2     company_id         (u16; 0xFFFF unless kind == 1)
4      16    uuid               (zeroed when kind == 1; 16/32-bit UUIDs promoted via the base UUID)
20     4     payload_len        (u32)
24     n     payload            (manufacturer additionalData with company id stripped, or
                                 service-data value, or characteristic/descriptor value)
```

## Output (CBOR)

Definite-length, integer-keyed CBOR:

```
{
  0: <summary text>?          ; optional one-line title
  1: [                        ; fields
    { 0: <key text>,          ; stable machine key
      1: <label text>,        ; human label
      2: <value>,             ; tstr | uint | negint | float64 | bool | bstr | tag37 bstr(uuid)
      3: <unit text>? }       ; optional unit
    , ...
  ]
}
```

- Byte fields use a CBOR byte string; UUID fields use tag 37 over a 16-byte string.
- **Integers carry no signedness.** CBOR major type 0 encodes any non-negative integer and major
  type 1 any negative one, so a semantically signed field (say a dBm power level) arrives as
  `uint` whenever its value is non-negative. The host's `DecodedValue.int` / `.uint` cases
  therefore mean "negative" / "non-negative", and they compare and hash numerically — a native
  parser emitting `.int(0)` equals a plugin emitting `.uint(0)`. Do not rely on the case to
  recover the guest's original type.
- The host decoder is strict: max depth 8, max 64 items per collection, max 1 KiB per string, and
  the total output must not exceed the manifest's `maxOutputBytes`.

## Manifest sidecar (`<name>.bleplugin.json`)

```json
{
  "manifestVersion": 1,
  "id": "org.example.plugin.foo",
  "name": "Foo",
  "version": "1.0.0",
  "abi": 1,
  "module": "foo.wasm",
  "sha256": "<lowercase hex of foo.wasm>",
  "matches": {
    "companyIdentifiers": [76],
    "serviceDataUUIDs": ["FEAA"],
    "characteristicUUIDs": ["2A19"],
    "descriptorUUIDs": []
  },
  "limits": { "maxMemoryPages": 16, "maxOutputBytes": 16384 }
}
```

Routing is driven entirely by `matches` — the host never executes a plugin for data it did not
declare. `sha256` is mandatory for user-imported plugins and verified before load.

## Resource limits & failure isolation

- Guest linear memory is capped at `maxMemoryPages` (default 16, ceiling 64) × 64 KiB.
- Each parse call has a wall-clock deadline (default 50 ms). The one-time cost of parsing,
  instantiating and `_initialize`-ing a module is bounded separately by a generous warmup deadline
  (default 5 s), and WasmKit compiles eagerly, so translation never lands on the per-call deadline.
  On timeout the plugin is **quarantined** (WasmKit has no execution interruption; the wedged call
  is abandoned).
- A trap, allocation failure, out-of-bounds result, oversized output, or malformed CBOR is a
  failure; three consecutive failures quarantine the plugin. Failures never propagate — the UI
  falls back to the raw hex view.
