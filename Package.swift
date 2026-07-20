// swift-tools-version: 6.2
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "bluetooth-explorer",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorer"])
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.7.1"),
        .package(url: "https://source.skip.tools/skip-model.git", from: "1.0.0"),
        .package(url: "https://github.com/MillerTechnologyPeru/skip-fuse-ui.git", branch: "feature/pureswift"),
        .package(url: "https://github.com/MillerTechnologyPeru/skip-fuse.git", branch: "feature/pureswift"),
        .package(url: "https://github.com/PureSwift/GATT.git", branch: "master"),
        .package(url: "https://github.com/PureSwift/AndroidBluetooth.git", branch: "master"),
        .package(url: "https://github.com/PureSwift/Bluetooth.git", from: "7.2.0"),
        .package(url: "https://github.com/swiftwasm/WasmKit.git", .upToNextMinor(from: "0.3.1"))
    ],
    targets: [
        .target(
            name: "BluetoothExplorer",
            dependencies: [
                "BluetoothExplorerUI",
                .product(
                    name: "SkipFuseUI",
                    package: "skip-fuse-ui"
                )
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .target(
            name: "BluetoothExplorerUI",
            dependencies: [
                "BluetoothExplorerModel",
                "BluetoothExplorerPluginEngine",
                .product(name: "SkipModel", package: "skip-model"),
                .product(name: "SkipFuse", package: "skip-fuse"),
                .product(name: "SkipFuseUI", package: "skip-fuse-ui")
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
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
                    name: "SkipFuse",
                    package: "skip-fuse"
                ),
                .product(
                    name: "SkipModel",
                    package: "skip-model"
                )
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
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
