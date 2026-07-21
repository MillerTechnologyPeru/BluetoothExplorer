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

Two `PureSwift` fixes are still required and are still open as PRs — `PureSwift/Android#43` and
`PureSwift/AndroidBluetooth#4`. Until they merge, local SwiftPM mirrors pointing at fixed clones are
needed; `AndroidBluetooth` otherwise fails with `product 'AndroidManifest' ... not found in package
'Android'`.

## What AndroidSwiftUI needed

The app's UI relies on SwiftUI that AndroidSwiftUI did not implement. These were added to
AndroidSwiftUI first (branch `feature/swiftui-containers`):

- `NavigationStack` — reusing the existing `NavigationContext`, so `NavigationLink` push and
  hardware-back pop are shared with `NavigationView` rather than duplicated
- `LazyVStack` / `LazyHStack` — eager, mapping onto the same LinearLayout path as `VStack`/`HStack`
- `TabView` with `.tabItem` and selection
- `.sheet(isPresented:content:)`
- `.refreshable`
- Swift **Observation** support — `.environment(object)` and `@Environment(Type.self)`, with
  invalidation driven by `withObservationTracking`

`.fileImporter` is not needed on Android: the plugin import button is already gated behind
`#if !os(Android)`.

## Platform status

- **Apple platforms** — the package resolves and every target builds with no Skip involvement.
- **Android** — the dependency wiring is in place, but the Android app build has not been verified
  end to end. It additionally needs the two PureSwift PRs above, and the Kotlin JNI peers under
  `Sources/BluetoothExplorer/Skip/` (`ScanCallback.kt`, `BluetoothGattCallback.kt`) rehomed into the
  Android app project — they are peers for `AndroidBluetooth`, unrelated to Skip, and were only
  living in that directory because skipstone collected them.
