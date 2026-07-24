# Migrating off Skip to AndroidSwiftUI

The app previously used [Skip](https://skip.tools) to compile its SwiftUI codebase for Android. It
now uses the system SwiftUI on Apple platforms and [PureSwift/AndroidSwiftUI](https://github.com/PureSwift/AndroidSwiftUI)
on Android.

## What Skip was doing

Skip's footprint was smaller than it appeared — nine `import` lines and one `Logger` — but it also
owned the build:

| Skip piece | Replacement |
|---|---|
| `SkipFuseUI` — SwiftUI for Android | `AndroidSwiftUI`, linked only `.when(platforms: [.android])` |
| `SkipModel` — Observation for Android | `import Observation` directly; the Swift Android SDK ships `Observation.swiftmodule` |
| `SkipFuse` — Foundation shims, `Logger` | `AppLogger` in `Sources/BluetoothExplorer/Logging.swift` (`os.Logger` on Apple, print-based elsewhere) |
| `skipstone` build plugin + three `skip.yml` | nothing — plain SwiftPM targets |
| `/* SKIP @bridge */` on the root view and app delegate | nothing — `Darwin/Sources/Main.swift` was already a real `@main` App |
| `ComposeView` / `#if SKIP` Compose interop in `ContentView` | removed with the rest of the Skip template scaffolding |
| `Skip.env` | removed |

Views now import conditionally:

```swift
#if canImport(SwiftUI)
import SwiftUI
#else
import AndroidSwiftUI
#endif
```

## The dependency-graph side effect

This removed the whole Skip fork stack — `skip-fuse`, `skip-fuse-ui`, `skip-android-bridge`,
`skip-ui`, `skip-foundation`, `skip-model`, and their transitive Java/JNI packages. The package
dropped from ~30 resolved dependencies to 20, and **the graph now resolves from a clean checkout**:

```sh
swift package resolve   # exit 0, no mirrors, no SWIFTPM_ENABLE_MACROS=0
```

Every blocker recorded in `Documentation/DependencyState.md` traced back to that stack:

- the `swift-android-native` two-URL conflict needed `skip-android-bridge` as one of the two
  claimants — with Skip gone there is only one claimant left;
- the `swift-java` / `swift-syntax` 603-vs-602 conflict came in through the same graph;
- `skip-fuse-ui` was the package that could not build against current `skip-ui`.

The two `PureSwift` fixes this once needed — `PureSwift/Android#43` and `PureSwift/AndroidBluetooth#4`
(both "Declare Apple platform requirements and fix the `AndroidManifest` dependency") — **merged on
2026-07-23**. So `AndroidBluetooth` no longer breaks Apple-platform resolution on its own. It is
still *not* declared here, for a different reason discovered afterward — see
[Why the Android build is still blocked](#why-the-android-build-is-still-blocked) below.

## What AndroidSwiftUI needed

The app's UI relies on SwiftUI that AndroidSwiftUI did not implement. These were added to
AndroidSwiftUI first (branch `feature/swiftui-containers`):

- `NavigationStack` — reusing the existing `NavigationContext`, so `NavigationLink` push and
  hardware-back pop are shared with `NavigationView` rather than duplicated
- `LazyVStack` / `LazyHStack` — eager, mapping onto the same LinearLayout path as `VStack`/`HStack`
- `TabView` with `.tabItem` and selection — tab items are read back by walking the modifier chain
  for trait-writing modifiers; only the selected tab is mounted
- `.sheet(isPresented:content:)` — a full-screen overlay in the same view hierarchy rather than an
  Android `Dialog`, because the fiber renderer mounts children into the parent's `ViewGroup` and has
  no path to a `Dialog`'s separate decor view
- `.refreshable` — stores a `RefreshAction` in the environment as SwiftUI does, but no gesture
  triggers it: binding `SwipeRefreshLayout` would need an androidx dependency the package lacks
- Swift **Observation** support — `.environment(object)` and `@Environment(Type.self)`, with
  invalidation driven by `withObservationTracking`

`.fileImporter` is not needed on Android: the plugin import button is already gated behind
`#if !os(Android)`.

### Known gaps in those additions

All four compile and were verified to build together for Android, but none has been exercised on a
device or emulator. Notable limitations, each documented in the source:

- **Observation**: `@Bindable` is not implemented, and `@Environment(Store.self) var store: Store?`
  (the optional form) is unsupported — a missing injection traps rather than yielding `nil`.
- **TabView**: unselected tabs are unmounted, so their `@State` resets; no `TabViewStyle`, paging or
  badges.
- **Sheet**: no animation, detents or drag-to-dismiss, and no `@Environment(\.dismiss)` — content
  must dismiss itself through the binding.
- **NavigationStack**: `NavigationStack(path:)` and value-based `navigationDestination(for:)` are
  not implemented; `NavigationContext.path` holds type-erased views, not a `Hashable` data path.

## Platform status

- **Apple platforms** — working end to end. A clean checkout resolves, builds, tests and archives
  with **no mirrors, no environment variables and no extra xcodebuild flags**, and the app runs in
  the simulator: the device list populates from `MockCentral`, and all 13 bundled plugins install
  into `Documents/Plugins/` on first launch and appear in the Plugins tab.

  Two things were needed to get there beyond removing Skip:
  - The `AndroidBluetooth` package dependency is not declared. Its old `AndroidManifest` bug (which
    broke Apple resolution) is fixed now, but declaring it currently fails resolution for a new
    reason — a Bluetooth version conflict — see below.
  - WasmKit is taken from a fork that drops `.treatAllWarnings(as: .error)`. Upstream's setting
    collides with the `-suppress-warnings` Xcode passes to package dependencies, which made the app
    unbuildable in Xcode; the override only works from the command line, so it could not be fixed
    from the xcconfig or project.
- **Android** — **does not build**, blocked entirely upstream (see
  [Why the Android build is still blocked](#why-the-android-build-is-still-blocked)). On Android the
  app falls back to `MockCentral`: `NativeCentral` resolves to `MockCentral` there, and the
  `AndroidBluetooth` import and `AndroidCentral` construction are removed from `NativeCentral.swift`
  and `Store.swift` until the dependency can be resolved again. `MockCentral` and its `Mock*` peers
  are compiled with `#if DEBUG || os(Android)` so the fallback is available in release too. The
  Kotlin JNI peers under `Sources/BluetoothExplorer/Skip/` (`ScanCallback.kt`,
  `BluetoothGattCallback.kt`) still belong in a real Android app project — they are peers for
  `AndroidBluetooth`, unrelated to Skip, and were only living in that directory because skipstone
  collected them.

## Why the Android build is still blocked

Both blockers are upstream packaging problems in the `PureSwift` dependency set, not anything in this
app's Swift code. Each was verified by trying:

1. **AndroidSwiftUI has no SwiftPM-consumable revision that also has the SwiftUI surface the app
   uses.** The views need `LazyVStack`, `.refreshable`, `.disabled`, `ProgressViewStyle.circular`
   and Observation's `@Environment(Store.self)`. Those shipped in AndroidSwiftUI **0.3.0**
   (2026-07-23). But:
   - `master` HEAD and the `0.3.0` tag both vend `AndroidSwiftUICore` as a `.package(path:)`
     sub-package, and SwiftPM forbids a **revision-based** (branch or commit) dependency from
     depending on a local package — so the app cannot pin AndroidSwiftUI by branch/revision.
   - `0.3.0` (a version tag) itself depends on `PureSwift/Android` by **branch**, and SwiftPM
     forbids a **version-pinned** package from depending on a branch ("package is required using a
     stable-version but depends on an unstable-version package") — so the app cannot pin it by
     version either.
   - The one branch-consumable revision, `ff646f48` (2026-07-16, the last commit before the
     sub-package split — and what `Package.resolved` currently pins), predates the features, so the
     views produce ~220 compile errors against it.

   The fix is upstream: either inline `AndroidSwiftUICore` back into a single target (so branch
   pinning works), or have AndroidSwiftUI depend on a *tagged* `Android` release (so the app can
   version-pin AndroidSwiftUI, which is allowed to carry a path sub-package). This is the same
   local-sub-package limitation noted for `BLEPluginSDK` consumers.

2. **`AndroidBluetooth` and `GATT` disagree on Bluetooth.** With #1 set aside, re-declaring
   `AndroidBluetooth` fails resolution because `AndroidBluetooth`'s `master` requires
   `Bluetooth 7.2.0..<8.0.0` while `GATT`'s `master` has moved to `Bluetooth 8.0.0..<9.0.0`. It
   resolves only by holding `GATT` at an older revision, which the app does not currently do.
   `AndroidBluetooth` needs a `master` that adopts Bluetooth 8.x.

Because of #1 the Android app cannot compile even with `MockCentral`, so the `.so` cannot be
produced yet. When AndroidSwiftUI becomes consumable, the app compiles for Android on `MockCentral`
with no further Swift changes; restoring real Bluetooth then additionally needs #2.

## Building an Android app archive

CI (`.github/workflows/ci.yml`) archives the iOS app but does **not** produce an Android `.aab`.
Several things block it, each verified by trying:

1. **The app does not cross-compile for Android**, because AndroidSwiftUI is not consumable at a
   featureful revision and `AndroidBluetooth` cannot be resolved alongside `GATT` — both detailed in
   [Why the Android build is still blocked](#why-the-android-build-is-still-blocked). These are the
   gating blockers; the ones below only matter once these are resolved.
2. **A whole-package Android build additionally fails in WasmKit's `SystemExtras`**: it does
   `st_mode & S_IFMT`, but `st_mode` is `UInt32` in the Android sysroot while swift-system's
   `CInterop.Mode` is `UInt16`. This target is not reachable from the app, so building specific
   targets avoids it; a plain `swift build` does not.
3. **The Android project is still Skip's.** `Android/settings.gradle.kts` shells out to
   `skip plugin --prebuild`, and `Android/app/build.gradle.kts` applies `skip-build-plugin` with a
   `skip { }` block that reads the now-deleted `Skip.env`. With Skip removed none of that resolves.

Replacing (3) means writing a conventional Android app project, using
[AndroidSwiftUI's `Demo/`](https://github.com/PureSwift/AndroidSwiftUI/tree/master/Demo) as the
template: its `app/src/main/java/com/pureswift/swiftandroid/` Kotlin classes (`MainActivity`,
`Application`, `NativeLibrary`, `ListViewAdapter`, `Fragment`, …) are the peers AndroidSwiftUI's
`@JavaClass` bindings bind to, and `build-swift.sh` shows the packaging step — build the Swift
package for the target architecture, then copy the resulting `.so` into
`app/src/main/jniLibs/<abi>/`. The Kotlin JNI peers currently under `Sources/BluetoothExplorer/Skip/`
(`ScanCallback.kt`, `BluetoothGattCallback.kt`) belong in that project too.

None of this is worth doing until (1) is fixed upstream, since the `.so` cannot be produced.
