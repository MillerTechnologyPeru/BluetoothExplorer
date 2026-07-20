# Dependency graph state (investigated 2026-07-19)

A clean checkout of this app cannot currently resolve its dependencies. This document records what
is broken, what has been fixed, and the one decision still outstanding.

Everything below was verified by running the builds, not inferred from manifests.

## Fixed

These are unambiguous bugs. Fixes are committed in the local fork checkouts under `~/Developer`
and are **not pushed** — review and push them before this app can build anywhere else.

### 1. Missing Apple platform declarations (15 iOS errors → 0)

`PureSwift/Android` and `PureSwift/AndroidBluetooth` declared only `.macOS(.v15)`. SwiftPM defaults
unspecified platforms to iOS 12, while their dependencies (`Bluetooth`, `GATT`, `Socket`) require
iOS 13 — so any Apple-platform resolve of a graph containing them failed with 15 errors like:

```
the library 'AndroidBluetooth' requires ios 12.0, but depends on the product 'Bluetooth'
which requires ios 13.0
```

Both now declare `.iOS(.v13), .watchOS(.v6), .tvOS(.v13)` to match. These packages only ever build
for Android, but SwiftPM validates platform requirements across the whole graph regardless.

- `PureSwift/Android` @ `17e1d1f`
- `PureSwift/AndroidBluetooth` @ `e061b99`

### 2. `AndroidManifest` moved packages

`PureSwift/Android` PR #40 moved `AndroidManifest` out into `swift-android-native`, but
`AndroidBluetooth` still imported it from `Android`, giving:

```
product 'AndroidManifest' required by package 'androidbluetooth' target 'AndroidBluetooth'
not found in package 'android'
```

`AndroidBluetooth` now depends on `swift-android-native` directly for it.

- `PureSwift/AndroidBluetooth` @ `6d5f5e1`

### 3. `swift-android-native` fork was unusable by half the graph

`MillerTechnologyPeru/swift-android-native` @ `feature/pureswift` was **87 commits behind upstream**,
and its "Add Skip prefix to conflicting packages" commit *renamed targets*
(`AndroidLogging` → `SkipAndroidLogging`, `AndroidLooper` → `SkipAndroidLooper`,
`AndroidNDK` → `SkipAndroidNDK`). Because a target's name is its module name, that rename made the
fork unusable by `PureSwift/Android`, which imports the upstream names — while `skip-android-bridge`
imports the Skip-prefixed ones. No single source satisfied both.

The fork branch now merges current upstream `main` and provides the Skip-prefixed names as **thin
re-export shim modules** (`@_exported import AndroidLogging`) instead of renaming. Both
`import AndroidLogging` and `import SkipAndroidLogging` now work, so one source serves everyone.

- `MillerTechnologyPeru/swift-android-native` @ `55a10f5` (merge), `978df30` (shims)

### 4. Bluetooth's swift-syntax range vs swift-java

`swift-java` requires swift-syntax 602+/603, while `PureSwift/Bluetooth` caps it below that. The
constraint exists only because Bluetooth builds macros, which it lets you disable:

```sh
SWIFTPM_ENABLE_MACROS=0 swift package resolve   # resolves cleanly
```

With macros disabled the graph resolves (verified, exit 0). The durable fix is to widen Bluetooth's
`swift-syntax` range and cut a release; until then, builds need this environment variable.

## Outstanding — needs a decision

**`swift-java` and `swift-java-jni-core` both declare a C target named `CSwiftJavaJNI`:**

```
multiple packages ('swift-java', 'swift-java-jni-core') declare targets with a conflicting
name: 'CSwiftJavaJNI'; target names need to be unique across the package graph
```

Upstream `swift-java` split its JNI core into a separate `swift-java-jni-core` package but still
declares the old target. Current `swift-android-native` (and `swift-jni`) depend on the split-out
package, while `PureSwift/Android`, `JavaLang` and `Kotlin` still depend on `swift-java`. Any graph
containing both breaks.

This cannot be fixed from the app: it needs the PureSwift Java stack migrated onto
`swift-java-jni-core`, or a `swift-java` revision that no longer declares `CSwiftJavaJNI`. That is a
coordinated migration across `Android`, `JavaLang` and `Kotlin`, and it is the reason the app-level
Android and iOS builds still cannot complete.

Attempting to pin backwards instead (older `GATT`, older `swift-java`) does not work: `GATT` master
has adopted SwiftPM traits and requires `Bluetooth` 7.5.0+, and an older `swift-java` reintroduces
the `CSwiftJavaJNI` clash from the other direction. The ecosystem is mid-migration on several fronts
at once, so the graph has to move forward, not back.

## Structural recommendation

`Package.resolved` is in `.gitignore`. That is why "it works on my machine" and a clean checkout
disagree — the working state exists only as an unversioned pin file, and every fresh resolve
re-derives it from floating `branch:` dependencies across a dozen actively-refactored repos.

Committing `Package.resolved` once the graph resolves again would make the app's dependency state
reproducible and stop this class of breakage from being invisible until someone clones the repo.

## Reproducing

```sh
# fails: CSwiftJavaJNI conflict
SWIFTPM_ENABLE_MACROS=0 swift build --triple arm64-apple-ios \
  --sdk $(xcrun --sdk iphoneos --show-sdk-path)

# the fork fixes above are consumed via local SwiftPM mirrors (machine-local, not committed):
swift package config set-mirror --package-url https://github.com/PureSwift/Android.git \
  --mirror-url file:///Users/coleman/Developer/Android
# ...same for AndroidBluetooth and MillerTechnologyPeru/swift-android-native
```
