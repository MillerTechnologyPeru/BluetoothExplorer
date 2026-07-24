// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bluetooth-explorer",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorer"]),
        // Guest-side SDK for authoring parser plugins, so consumers can depend on this package and
        // `import BLEPluginSDK` from their wasm plugin. It is not a dependency of the app, so the app
        // and the iOS archive never build it. Sources are shared with the standalone
        // `PluginSDK/BLEPluginSDK` package that the in-repo example plugins use.
        .library(name: "BLEPluginSDK", targets: ["BLEPluginSDK"])
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/GATT.git", branch: "master"),
        // AndroidBluetooth is not declared. Its old `AndroidManifest` problem is fixed
        // (PureSwift/AndroidBluetooth#4, PureSwift/Android#43, both merged 2026-07-23), but declaring
        // it now fails resolution differently: AndroidBluetooth's `master` pins Bluetooth 7.2.x while
        // GATT's `master` moved to Bluetooth 8.x. On Android the app falls back to `MockCentral`
        // instead of `AndroidCentral` for now — see Documentation/AndroidSwiftUIMigration.md. Restore
        // this and the `AndroidBluetooth` target dependency once AndroidBluetooth adopts Bluetooth 8.
        .package(url: "https://github.com/PureSwift/Bluetooth.git", from: "7.2.0"),
        // SwiftUI for Android. Apple platforms use the system SwiftUI instead, so this is only
        // linked for .android — see the conditional target dependencies below.
        .package(url: "https://github.com/PureSwift/AndroidSwiftUI.git", branch: "master"),
        // Fork of WasmKit 0.3.1 with one change: upstream declares
        // `.treatAllWarnings(as: .error)` for Apple platforms, which collides with the
        // `-suppress-warnings` Xcode passes to package dependencies and makes the app fail to build
        // in Xcode ("Conflicting options '-warnings-as-errors' and '-suppress-warnings'"). That
        // setting only reaches package targets from the command line, so it cannot be overridden
        // from the xcconfig or the project. Track upstream and drop the fork once it is fixed there.
        .package(
            url: "https://github.com/MillerTechnologyPeru/WasmKit.git",
            revision: "ba06b7c64b5bc692c19c301ba2ef843c8d0f37c2"
        )
    ],
    targets: [
        .target(
            name: "BluetoothExplorer",
            dependencies: [
                "BluetoothExplorerUI",
                .product(
                    name: "AndroidSwiftUI",
                    package: "AndroidSwiftUI",
                    condition: .when(platforms: [.android])
                )
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "BluetoothExplorerUI",
            dependencies: [
                "BluetoothExplorerModel",
                "BluetoothExplorerPluginEngine",
                .product(
                    name: "AndroidSwiftUI",
                    package: "AndroidSwiftUI",
                    condition: .when(platforms: [.android])
                )
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "BluetoothExplorerPluginEngine",
            dependencies: [
                .product(name: "WasmKit", package: "WasmKit"),
                .product(name: "Bluetooth", package: "Bluetooth")
            ],
            resources: [.copy("Plugins")]
        ),
        .target(
            name: "BluetoothExplorerModel",
            dependencies: [
                "BluetoothExplorerPluginEngine",
                .product(
                    name: "GATT",
                    package: "GATT"
                ),
                .product(
                    name: "DarwinGATT",
                    package: "GATT",
                    condition: .when(platforms: [.macOS, .iOS, .macCatalyst, .watchOS, .tvOS, .visionOS])
                ),
                .product(
                    name: "AndroidSwiftUI",
                    package: "AndroidSwiftUI",
                    condition: .when(platforms: [.android])
                )
            ],
            resources: [.process("Resources")]
        ),
        // Embedded-Swift-safe helpers for plugin authors: envelope decoding, a payload cursor, a
        // CBOR field builder, and the allocation/return glue. Built in Embedded mode (it compiles
        // for the host too, though nothing runs it there).
        .target(
            name: "BLEPluginSDK",
            path: "PluginSDK/BLEPluginSDK/Sources/BLEPluginSDK",
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .unsafeFlags(["-wmo"])
            ]
        ),
        .testTarget(
            name: "BluetoothExplorerPluginEngineTests",
            dependencies: [
                "BluetoothExplorerPluginEngine",
                .product(name: "WAT", package: "WasmKit"),
                // Oracle for the GATT characteristic plugins: the same bytes are run through
                // BluetoothGATT's own parsers and the plugins must agree on accept/reject.
                .product(name: "BluetoothGATT", package: "Bluetooth")
            ]
        ),
        .testTarget(
            name: "BluetoothExplorerModelTests",
            dependencies: ["BluetoothExplorerModel"]
        )
    ]
)
