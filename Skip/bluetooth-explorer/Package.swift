// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "bluetooth-explorer",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorer"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.5"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        .package(url: "https://github.com/PureSwift/GATT.git", branch: "master")
    ],
    targets: [
        .target(
            name: "BluetoothExplorer",
            dependencies: [
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "GATT", package: "GATT"),
                "BluetoothExplorerModel"
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .target(
            name: "BluetoothExplorerModel",
            dependencies: [
                .product(name: "GATT", package: "GATT")
            ]
        ),
        .testTarget(
            name: "BluetoothExplorerTests",
            dependencies: [
            "BluetoothExplorer",
                .product(name: "SkipTest", package: "skip")
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        )
    ]
)
