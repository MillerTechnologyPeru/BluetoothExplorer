# WASM Plugin Runtime & SDK — Implementation Plan

Goal: make parsing of BLE advertisements (manufacturer data, service data) and GATT
characteristic/descriptor values pluggable. Plugins are `.wasm` modules loaded at runtime,
authored against a small SDK, running identically on iOS, macOS, and Android (Skip Fuse
native Swift).

---

> **Implementation status (M0–M2 + app integration done).** The runtime, host engine, native
> parsers, ABI, a bundled reference plugin, tests, and full Store/UI integration are implemented and
> building. See `Sources/BluetoothExplorerPluginEngine/`, `Documentation/PluginABI.md`, and the
> M0-driven pin change below. Remaining: guest SDK repo (Rust PDK + `bleplug` CLI), user-import UX
> (M4), and the Android build verification (still a gate — see §9).

## 1. Runtime decision: WasmKit 0.3.x (app floor raised to iOS 18 / macOS 15)

Embed [swiftwasm/WasmKit](https://github.com/swiftwasm/WasmKit), pinned
`.upToNextMinor(from: "0.3.1")`.

**M0 finding and decision:** WasmKit 0.3.x declares `platforms: [.macOS(.v15), .iOS(.v18)]` in its own
Package.swift. Rather than downgrade to WasmKit 0.2.2 (which supports iOS 12 / macOS 10.13 but forces
a swift-system 1.5.x pin because its `SystemExtras` won't build against swift-system ≥ 1.7), we
**raised the app's platform floor to iOS 18 / macOS 15** — in `Package.swift` and in
`Darwin/BluetoothExplorer.xcconfig`. This keeps 0.3.x's ongoing SIMD / exception-handling /
component-model work and avoids the swift-system pin (it resolves to 1.7.4 cleanly). Verified: the
engine target and all 20 tests build and pass against 0.3.1. See the `wasmkit-version-pin` memory.

- Pure-Swift register-machine interpreter — no JIT, no `PROT_EXEC` → App Store safe.
- The only runtime whose primary embedding API is Swift (`Engine`/`Store`/`Module`/`Instance`,
  closure host functions, `Memory.withUnsafe(Mutable)BufferPointer`). No C wrapper to maintain.
- SwiftPM-only with one tiny internal C target (`_CWasmKit`) — compatible with Skip Fuse
  `mode: native` (NDK clang compiles C targets). Upstream CI covers iOS 12+ and Android API 30+.
- Toolchain-adjacent maintenance: ships in official swift.org toolchains since Swift 6.2;
  0.3.x requires Swift 6.3 (host toolchain here is 6.3.3 / Xcode 26.6 — satisfied on Darwin;
  the Swift **Android** SDK version used by `skip plugin --prebuild` must be verified in M0).
- Performance: interpreter tier (~5–15× native). A ≤31-byte advertisement parse with a warm
  `Instance` is tens of µs — comfortably inside a sub-ms per-event budget.

**Known gap:** no fuel metering and no execution interruption. Mitigation is layered
(memory caps via `ResourceLimiter`, low `stackSize`, wall-clock deadline with
thread abandonment, quarantine **after the first timeout** — an abandoned spinning thread is a
battery/thermal incident on mobile, not just a leaked resource). **WAMR (fast-interp)** is the
documented fallback runtime if hard hostile-module containment ever becomes a requirement
(it has `wasm_runtime_terminate` + instruction metering, at the cost of C/CMake integration).

Rejected: wasm3 (minimal-maintenance since Dec 2023, frozen near Wasm 1.0), wasmtime
(tier-3 iOS via Pulley, huge Rust artifact, no perf win at interpreter tier, poor Skip fit),
JavaScriptCore (cannot run wasm in-process on iOS at all; Android has no system JSC),
Extism (no Swift host SDK; wasmtime-based — copy its manifest/ABI ideas only).

## 2. App Store policy stance (decide before building install UX)

- **Bundled** plugins: unambiguously fine.
- **User-imported** plugins: defensible under Apple DPLA §3.3.1(B) (downloaded *interpreted*
  code is permitted if it doesn't change the app's primary purpose, doesn't create a
  storefront, doesn't bypass OS security). Decoding BLE data *is* the app's advertised
  purpose, so import-from-Files is a reasonable review risk — but it is a judgment call,
  not settled precedent.
- **Never build an in-app plugin directory/marketplace/browser** — that runs straight into
  the "storefront for other code" prohibition (Guideline 2.5.2 / 3.3.1(B)). Distribution
  stays out-of-app (GitHub, direct file sharing).

## 3. Architecture overview

```
┌────────────────────────────── app ──────────────────────────────┐
│ BluetoothExplorerUI                                             │
│   DecodedFieldsView, PluginsView, updated AttributeValueCell /  │
│   CentralCell / PeripheralView                                  │
│ BluetoothExplorerModel                                          │
│   Store (@MainActor) ── hooks in found()/readValue()/           │
│   notification() → async decode → decoded* state dicts          │
│ BluetoothExplorerPluginEngine   (NEW target)                    │
│   ParserPlugin protocol + ParserRegistry (routing)              │
│   Native built-ins: iBeacon, well-known characteristics         │
│   PluginManager (@Observable: discover/install/enable/reload)   │
│   PluginEngine actor → WasmKit (per-plugin Store/Instance,      │
│   ResourceLimiter, deadline watchdog, quarantine)               │
└─────────────────────────────────────────────────────────────────┘
   ble-plugin-sdk (separate repo)
     spec/ABI.md + conformance vectors (normative, frozen first)
     rust/ble-plugin-pdk   (reference PDK, wasm32-unknown-unknown)
     swift/BLEPluginSDK    (Embedded Swift, wasip1 reactor, template)
     bleplug CLI           (new / run / pack / conformance)
     examples/             (ibeacon, heart-rate, battery-level)
```

Key layering choice: the `ParserPlugin` protocol + registry ship **before** any wasm code,
with the existing native decoders (`AppleBeacon` iBeacon parser, the
`BluetoothUUID.description(for:)` switch) re-wrapped as built-in registry entries. The app
gets the decoded-fields UI and routing in a fully shippable milestone with zero wasm risk;
WasmKit plugins then join the same registry.

## 4. Normative ABI v1 — freeze first, in `spec/ABI.md`

The three drafts produced during design diverged on envelope encoding, UUID byte order, and
export names. **One byte-level spec with test vectors must be written and frozen before any
host or SDK code.** The decisions:

**Module forms accepted:** import-free core module (`wasm32-unknown-unknown`) — canonical;
or `wasm32-unknown-wasip1` **reactor** (for Embedded Swift; host links WASI with *no*
preopens/env/args — allocator plumbing only; host calls `_initialize` once). Any other
import ⇒ load rejection. No host-callback imports in v1 (one-directional trust boundary).

**Exports:**

| Export | Signature | Notes |
|---|---|---|
| `bleplug_abi_1` | `() -> ()` | version marker, never called (proxy-wasm pattern) |
| `bleplug_alloc` | `(size: u32) -> u32` | guest owns all allocation; 0 = failure; arena semantics allowed |
| `memory` | linear memory | required |
| `bleplug_parse_manufacturer` | `(ptr: u32, len: u32) -> u64` | optional — presence = capability |
| `bleplug_parse_service_data` | `(ptr: u32, len: u32) -> u64` | optional |
| `bleplug_parse_characteristic` | `(ptr: u32, len: u32) -> u64` | optional |
| `bleplug_parse_descriptor` | `(ptr: u32, len: u32) -> u64` | optional |
| `bleplug_free` | `(ptr: u32, size: u32) -> ()` | optional |
| `bleplug_reset` | `() -> ()` | optional arena reset between calls |
| `_initialize` | | wasip1 reactor init |

Return `u64 = (result_ptr << 32) | result_len`; `0` = "not mine / no parse" (not an error);
trap = plugin failure. Only i32/i64 cross the boundary.

**Input envelope** — fixed little-endian binary header + payload (trivially readable from
`no_std` Rust and Embedded Swift, no decoder dependency):

```
offset size  field
0      1     envelope_version (=1)
1      1     kind (1=manufacturer, 2=serviceData, 3=characteristic, 4=descriptor)
2      2     company_id  (LE u16; 0xFFFF unless kind=1)
4      16    uuid        (RFC-4122 BIG-ENDIAN, always; 16/32-bit UUIDs promoted via the
                          Bluetooth base UUID; zeroed when kind=1)
20     4     payload_len (LE u32)
24     n     payload     (manufacturerData.additionalData with company ID stripped, or
                          service-data value, or characteristic/descriptor value)
```

UUID byte order is the one place plugin authors *will* get wrong (SIG UUIDs are LE on air,
iBeacon proximity UUIDs are BE inside the payload): the spec fixes **RFC-4122 big-endian
everywhere in envelope and output**; conversion is the host's job. Test vectors enforce it.

**Output: CBOR** (RFC 8949), definite-length, integer-keyed, strict subset:
`{0: summary?, 1: [ {0: key, 1: label, 2: value, 3: unit?} ]}`; value = tstr | int | float64 |
bool | bstr (bytes) | tag-37 bstr (UUID). Host decoder is a hand-rolled ~300-line strict
reader (depth ≤ 8, ≤ 64 fields, strings ≤ 1 KiB, `maxOutputBytes` cap) — strictness is a
security feature; plugin output is untrusted input.

**Purity rule (ABI contract):** parse functions must be pure functions of the envelope.
The host MAY cache results for identical inputs and MAY reset/recycle instances at any time.
(This resolves the memoization-vs-warm-state contradiction: stateful plugins are simply
out of contract.)

**Memory-safety rule for the host:** re-acquire the memory view *after* every guest call —
`memory.grow` during a call can reallocate linear memory; never cache a buffer pointer
across a call.

**Versioning:** major = new marker export (`bleplug_abi_2`); minor = new optional exports +
appended envelope fields gated by `envelope_version` (guests ignore trailing bytes, hosts
ignore unknown exports). Every function is bytes-in/bytes-out, so a future WIT/component-
model migration is mechanical (component model is not practical for Swift hosts in 2026).

**Manifest** — JSON sidecar `<name>.bleplugin.json` next to `<name>.wasm`:

```json
{
  "manifestVersion": 1,
  "id": "org.pureswift.plugin.ibeacon",
  "name": "Apple iBeacon",
  "version": "1.0.0",
  "abi": 1,
  "module": "ibeacon.wasm",
  "sha256": "…",
  "matches": {
    "companyIdentifiers": [76],
    "serviceDataUUIDs": ["FEAA"],
    "characteristicUUIDs": ["2A37"],
    "descriptorUUIDs": []
  },
  "limits": { "maxMemoryPages": 16, "maxOutputBytes": 16384 }
}
```

Routing comes from the manifest (exact-key dictionary lookups: company → plugins,
UUID → plugins). The host never executes wasm speculatively and never iterates all plugins
per advertisement. No wildcard matching in v1. Load-time validation: `abi == 1`, sha256
match (mandatory for imported plugins), declared matches ⇔ capability exports, module parses
under `ParsingLimits`, file-size cap before parsing.

## 5. Host implementation (app repo)

### 5.1 Package changes

```swift
.package(url: "https://github.com/swiftwasm/WasmKit.git", .upToNextMinor(from: "0.3.1")),
.package(url: "https://github.com/PureSwift/Bluetooth.git", .upToNextMajor(from: "7.2.4")), // now direct

.target(
    name: "BluetoothExplorerPluginEngine",
    dependencies: [
        .product(name: "WasmKit", package: "WasmKit"),
        .product(name: "Bluetooth", package: "Bluetooth"),  // BluetoothUUID, CompanyIdentifier
        .product(name: "SkipFuse", package: "skip-fuse"),
    ],
    resources: [.copy("Plugins")],   // .copy, NOT .process — opaque .wasm blobs
    plugins: [.plugin(name: "skipstone", package: "skip")]
),
.testTarget(name: "BluetoothExplorerPluginEngineTests", ...)
```

Plus the mandatory `Sources/BluetoothExplorerPluginEngine/Skip/skip.yml` with
`skip: {mode: 'native'}` — without it the target is not processed for Android.
`BluetoothExplorerModel` depends on the new target. Before touching Package.swift, pin the
six branch-based dependencies (skip-fuse forks, GATT/AndroidBluetooth master) to revisions —
adding a dependency rewrites `Package.resolved` and can float them.

Separate target rationale: WasmKit stays isolated behind the `ParserPlugin` protocol, so the
Android spike can fail without blocking model work, registry/Store tests run wasm-free, and a
WAMR swap would touch only this target.

### 5.2 Files

```
Sources/BluetoothExplorerPluginEngine/
  Skip/skip.yml
  DecodedField.swift            // output model
  ParserPlugin.swift            // protocol + AdvertisementInput/CharacteristicInput
  ParserRegistry.swift          // immutable routing snapshot, dictionary lookups
  NativeParsers.swift           // iBeacon + well-known-characteristic built-ins
  PluginManifest.swift          // Codable + validation
  PluginManager.swift           // @Observable: discovery, import, enable/disable, reload
  Wasm/PluginEngine.swift       // actor owning WasmKit Engine + per-plugin instances
  Wasm/WasmParserPlugin.swift   // ParserPlugin conformance over one module
  Wasm/PluginABI.swift          // envelope encode, u64 unpack, export names
  Wasm/MicroCBOR.swift          // strict subset decoder (no third-party dep)
  Wasm/PluginResourceLimiter.swift
  Plugins/                      // bundled .wasm + .bleplugin.json
```

### 5.3 Core types

```swift
public struct DecodedField: Hashable, Sendable, Identifiable {
    public let key: String        // stable machine key ("major")
    public let label: String      // display label ("Major")
    public let value: DecodedValue // .string/.int/.uint/.double/.bool/.bytes/.uuid
    public let unit: String?      // "%", "bpm", "dBm"
}
public struct DecodedResult: Sendable {
    public let pluginID: PluginID
    public let title: String?     // "iBeacon" — one-line summary for list cells
    public let fields: [DecodedField]
}

public protocol ParserPlugin: Sendable {
    var id: PluginID { get }
    var manifest: PluginManifest { get }
    func parseAdvertisement(_ input: AdvertisementInput) async throws -> DecodedResult?
    func parseCharacteristic(_ input: CharacteristicInput) async throws -> DecodedResult?
}
```

### 5.4 Execution model, sandboxing, failure isolation

- One WasmKit `Engine` (lazy compilation) per `PluginEngine`; one `Store` + warm `Instance`
  per plugin, reused across calls (the tens-of-µs guarantee). `Module` parsed lazily on
  first actual match — manifest scan at startup is JSON-only, zero wasm work at app launch.
- Each plugin's calls are serialized on its **own dedicated thread** (not the Swift
  Concurrency cooperative pool — an abandoned runaway must not starve the pool);
  `PluginEngine` awaits a continuation with a deadline (default 50 ms).
- On deadline: abandon the thread, **quarantine the plugin immediately** (first timeout, not
  third), surface the error in the plugins UI. On trap/malformed output/alloc failure:
  3-strikes circuit breaker, instance recycled from the cached `Module`. Failures never
  propagate — worst case the UI shows hex, exactly as today.
- Memory: `ResourceLimiter` caps growth at `min(manifest.maxMemoryPages, 64) × 64 KiB`
  (hard ceiling 4 MiB); `EngineConfiguration.stackSize` ≈ 512 KiB; module file-size cap.
- Result memoization: LRU (≈256) keyed by `(pluginID, kind, key, payload-hash)` — legal
  because the ABI declares purity. The fingerprint check runs synchronously in
  `found(scanData:)` **before** spawning any Task (Task-per-advertisement at dense-scan
  rates is itself a cost).
- Global controls: a plugin-system kill switch in Settings, and a wasm-CPU budget
  (e.g. max wasm ms per scan-second; over budget → skip decodes until the next window) —
  ambient BLE traffic driving continuous interpreter work is an Android-vitals/battery risk.
- Instance recycling every N=1024 calls, after any trap, and on memory pressure (drop
  instances, keep `Module`; drop `Module` for plugins unused > 60 s).
- Plugin output strings rendered with `Text(verbatim:)` only.

### 5.5 Store hooks (`Sources/BluetoothExplorerModel/Model/Store.swift`)

Precondition: give `AttributeValue` a proper unique `id` (UUID) — it is currently
`Identifiable` by `date`, and notification bursts can collide on timestamps.

- New state: `decodedAdvertisements: [Peripheral: [DecodedResult]]`,
  `decodedValues: [Characteristic: [AttributeValue.ID: DecodedResult]]`, and the descriptor
  equivalent. `PluginManager` is a property of `Store` (injected in `init(central:)`,
  Store.swift:91); screens reach it via the existing `@Environment(Store.self)`.
- `found(scanData:)` (Store.swift:171): after `cache += scanData`, synchronous fingerprint
  check → if changed, `Task { decodedAdvertisements[peripheral] = await registry.decode… }`.
- `readValue` / `notification` / descriptor reads (Store.swift:244, 284, 297): after
  appending the `AttributeValue`, async decode into `decodedValues`; evict entries whose
  value left the capacity-10 `Cache`.
- Writes are decoded too, labeled in the UI as *decoded intent* ("what you asked to write"),
  distinct from read/notify on-wire decodes.
- Phase 2 (M4): stop dropping raw `manufacturerData` when an iBeacon parses
  (ScanDataCache.+=, Store.swift:364-368) and let the built-in iBeacon parser own beacon
  decoding; `CentralListViewModel.ScanResult.beacon` then reads from `decodedAdvertisements`.
  UI-visible change — gate with the milestone that updates `CentralCell`.

### 5.6 UI changes (`Sources/BluetoothExplorerUI`)

- `DecodedFieldsView.swift` — renders `[DecodedField]` as label/value rows; `bytes` as
  `"0x" + toHexadecimal()`; no `ByteCountFormatter` (Android-gated today).
- `AttributeValueCell` (AttributeValueCell.swift:64-85) display priority: decoded fields
  (+ "via <plugin>" caption) → existing `uuid.description(for:)` → hex fallback. Also fix
  the Android branch to use `toHexadecimal()` (pure Swift, works there).
- `AttributeValuesSection` / `CharacteristicView` / `DescriptorView` thread the
  `[AttributeValue.ID: DecodedResult]` lookup through.
- `PeripheralView`: new "Decoded" section above the raw manufacturer-data section — raw and
  decoded side by side (it's an explorer app; keep the raw bytes visible).
- `CentralCell`: generic decoded-summary lines replace the hardcoded beacon block (M4).
- `PluginsView.swift`: list with enable/disable toggles, version, source badge, error text,
  Import… (`.fileImporter`, `#if !os(Android)` initially — SkipFuseUI support unverified;
  Android fallback: documents-dir pickup, later a Kotlin SAF shim like `ScanCallback.kt`),
  swipe-to-delete for imported plugins. Entry from `SettingsView` (ContentView.swift:50-72).

### 5.7 Plugin lifecycle

- Bundled: `Bundle.module` scan of `Plugins/` (pairs of `.wasm` + `.bleplugin.json`).
- Imported: Application Support `/Plugins/<id>/`; enable/disable persisted in UserDefaults.
- Import validation: manifest parse, abi check, sha256, `parseWasm`, export/capability
  consistency, trial instantiation under the limiter — reject with a user-visible error.
- Trust model v1: user-imported plugins are trusted-by-the-user; containment = zero/null
  imports + memory caps + deadline + quarantine. No signing in v1; decide the authenticity
  story before any non-local distribution (and see §2 — no marketplace, ever).

## 6. Guest SDKs (`ble-plugin-sdk`, separate repo)

- **`spec/ABI.md` + `spec/vectors/*.json`** — the normative spec (§4) and conformance
  vectors (hex input → expected fields). Everything else conforms to this.
- **Rust reference PDK** (`ble-plugin-pdk`, `no_std` + alloc, `wasm32-unknown-unknown`):
  author writes one pure function over `AdvertisementInput`/`Fields`; a `ble_plugin!` macro
  emits the exports, allocator, and CBOR (minicbor). `opt-level="z"` + lto + `panic="abort"`
  + `wasm-opt -Oz` → 1–30 KB. This is the always-working path.
- **Embedded Swift SDK** (`BLEPluginSDK`, wasip1 reactor, `swift-6.3_wasm-embedded` SDK,
  pinned): same author experience (`PayloadReader`, `Fields` builder, hand-rolled ~100-line
  CBOR emitter — Embedded-safe: no existentials, no Codable, no Foundation). Because
  `@_expose(wasm)` symbols are dropped from dependency modules (swiftlang/swift #77812), the
  export shims live in the **author's module via template**, not in the SDK library.
  Flagship but experimental — docs must not promise parity with Rust. Sizes: tens–hundreds
  of KB. AssemblyScript documented; TinyGo tolerated; full non-embedded Swift explicitly
  unsupported (9–50 MB binaries).
- **`bleplug` CLI**: `new` (scaffold), `run <plugin.wasm> --adv --company 004C --hex …`
  (instant feedback under real WasmKit, no app/device), `pack` (validate exports vs
  manifest, sha256, emit pair), `conformance` (run vectors).
- **Two-tier author testing**: the parse function is a plain function — unit-test it
  natively with LLDB; only the thin shim needs wasm-level conformance runs.
- **Reference plugins** (examples + bundled in the app):
  1. `battery-level.wasm` (Rust, ~1 KB) — 0x2A19; the "hello world"; also exercises
     coexistence with the native decoder for the same UUID.
  2. `ibeacon.wasm` (Rust) — conformance twin of the native `AppleBeacon` parser; tests
     diff their outputs byte-for-byte on the `MockAdvertisement` fixtures.
  3. `heart-rate.wasm` (Embedded Swift) — 0x2A37 flags/8-16-bit BPM/RR intervals; fills a
     real gap (`GATTHeartRateMeasurement` doesn't exist in BluetoothGATT) and exercises
     notifications live with any HR strap.
  4. (Post-v1) Eddystone 0xFEAA — exercises the service-data route.
  Built artifacts checked into the app repo; SDK-repo CI rebuilds and diffs hashes.

## 7. Testing

- WAT fixtures via WasmKit's bundled `wat2wasm`: well-behaved / returns-0 / traps /
  out-of-bounds result / oversized output / memory-growth-past-limiter / missing exports /
  infinite loop (→ quarantine + thread accounting) / malformed-CBOR fuzz corpus.
- Conformance vectors run against every bundled plugin in app CI and by authors via the CLI.
- Integration: `MockCentral` fixtures → `Store` → assert `decodedAdvertisements` /
  `decodedValues` populated. The simulator uses `MockCentral`, so wire MockAdvertisement
  fixtures through the registry deliberately — that's the day-to-day dev inner loop.
- Android: on-device smoke test (instantiate `ibeacon.wasm`, parse one fixture) wired into
  the Gradle build early; profile decode load on low-end hardware against the CPU budget.

## 8. Milestones

**M0 — Feasibility spike (3–5 days, hard gate).**
1. `swift --version` inside the Skip Android prebuild — is the Swift Android SDK ≥ 6.3?
   (Darwin host is 6.3.3 — already satisfied.) Fallback: WasmKit 0.2.x (Swift 6.0 MSSV;
   loses SIMD/EH, irrelevant for parsers).
2. `swift package resolve` dry run with WasmKit added — check the swift-system version
   conflict risk against the PureSwift Socket/GATT/swift-android-native graph (0.3.1's
   raison d'être was a swift-system bump). Pin branch deps to revisions first.
3. Full Android build via `skip plugin --prebuild`: `_CWasmKit` under NDK 27, and WasmKit's
   documented Android floor (API 30) vs the app's minSdk 28 — test on 28/29 or raise minSdk.
4. Instantiate a hello-world module from a unit test on macOS, an iOS device, and Android.
5. Verify `.copy` resources (an opaque binary blob) land in the APK and resolve via
   `Bundle.module` under SkipFuse Foundation (only a `.process`'d .xcstrings exists today;
   fallback: base64-embed bundled plugins in source).
Go/no-go on WasmKit vs the WAMR fallback. Deliverable: findings + throwaway branch.

**M0.5 — Freeze `spec/ABI.md` + vectors (2–3 days).** §4 verbatim, byte-level, with
golden vectors (including UUID-endianness traps). No host/SDK code before this lands.

**M1 — Native registry + decoded-fields UI (1–1.5 weeks, shippable).**
New target with protocol/registry/`DecodedField` (no WasmKit code paths active). iBeacon +
`BluetoothUUID.description` become built-in parsers. `AttributeValue.id` fix. Store hooks +
state. `DecodedFieldsView`, cell priority chain, `PeripheralView` Decoded section.
MockCentral tests. App behaves identically-or-better with zero wasm.

**M2 — Wasm execution (2–3 weeks, shippable).**
`PluginEngine` actor, ABI v1 host side, MicroCBOR, resource limiter, deadline/quarantine,
memoization + CPU budget + kill switch. Bundled battery + iBeacon (Rust) plugins.
`PluginManager` bundled discovery + enable/disable. Basic `PluginsView` (toggles).
Golden-file tests both platforms.

**M3 — SDK + author tooling (2 weeks, parallelizable with M2 tail).**
`ble-plugin-sdk` repo: Rust PDK + macro, `bleplug` CLI, conformance harness, Embedded Swift
template + pinned toolchain docs, heart-rate reference plugin, docs site page.

**M4 — User-imported plugins + hardening (1.5–2 weeks).**
`.fileImporter` flow (iOS/macOS), validation pipeline, Application Support storage,
remove/reload UI, error surfacing; Android documents-dir import (SAF shim later).
Remove the iBeacon special case from `ScanDataCache.+=` (keep raw manufacturerData);
`CentralCell` generic decoded lines; delete the `BluetoothUUID.description` shim;
battery/perf profiling on low-end Android.

Total ≈ 8–11 weeks. M1 and M2 are each independently shippable.

## 9. Top risks

| Risk | Mitigation |
|---|---|
| WasmKit unverified under this exact Skip Fuse fork stack (feature/pureswift branches, NDK 27, minSdk 28 vs API-30 floor) | M0 hard gate; WAMR fallback documented |
| swift-system version conflict in the dependency graph | M0 `swift package resolve` dry run; pin branch deps to revisions first |
| No fuel/interruption in WasmKit — runaway plugin = abandoned spinning thread | dedicated thread per plugin, quarantine on first timeout, memory caps, CPU budget + kill switch; WAMR if containment becomes hard requirement |
| App Store review of user-imported plugins (2.5.2 / 3.3.1(B)) | bundled-first rollout; import framed as same-purpose interpreted content; no marketplace ever |
| `.copy` binary resources through skipstone into the APK unproven | M0 item 5; base64-embed escape hatch |
| Embedded Swift toolchain churn (#77812 export-dropping, duplicate-symbol issues) | shims-in-template design, pinned SDK versions, Rust as reference PDK |
| Dense-environment scan load (dozens of devices × ~10 adv/s) at interpreter speed | synchronous fingerprint dedupe before Task spawn, manifest-only routing, memoization, CPU budget; profile on low-end Android |
| Hand-rolled CBOR in three places (host Swift, Embedded Swift, minicbor) | shared conformance vectors exercised on all three |

## 10. Deliberately deferred / rejected

- Component model / WIT (not practical for Swift hosts in 2026; bytes-in/bytes-out ABI keeps
  migration mechanical). Wildcard advertisement matching (puts every plugin on the hot
  path). Host-callback imports like `log` (ABI 1.1 candidate; requires writing reentrancy
  rules first). Write-path *encoders* (structured editor → bytes) — natural
  `bleplug_encode_characteristic` extension, out of v1. Plugin signing/marketplace.
  Raw-AD-structure access (Darwin never exposes it; envelope carries pre-extracted payloads
  so both platforms feed plugins identically).
