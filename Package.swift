// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bluetooth-explorer",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorer"])
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/GATT.git", branch: "master"),
        .package(url: "https://github.com/PureSwift/AndroidBluetooth.git", branch: "master"),
        .package(url: "https://github.com/PureSwift/Bluetooth.git", from: "7.2.0"),
        // SwiftUI for Android. Apple platforms use the system SwiftUI instead, so this is only
        // linked for .android — see the conditional target dependencies below.
        .package(url: "https://github.com/PureSwift/AndroidSwiftUI.git", branch: "master"),
        .package(url: "https://github.com/swiftwasm/WasmKit.git", .upToNextMinor(from: "0.3.1"))
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
                    name: "AndroidBluetooth",
                    package: "AndroidBluetooth",
                    condition: .when(platforms: [.android])
                ),
                .product(
                    name: "AndroidSwiftUI",
                    package: "AndroidSwiftUI",
                    condition: .when(platforms: [.android])
                )
            ],
            resources: [.process("Resources")]
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
        )
    ]
)
