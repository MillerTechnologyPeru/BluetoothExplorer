// swift-tools-version: 6.2
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "bluetooth-explorer",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorer"])
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.7.1"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-fuse.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-model.git", from: "1.0.0"),
        .package(url: "https://github.com/PureSwift/GATT.git", branch: "master")
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
                .product(name: "SkipModel", package: "skip-model"),
                .product(name: "SkipFuse", package: "skip-fuse"),
                .product(name: "SkipFuseUI", package: "skip-fuse-ui")
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .target(
            name: "BluetoothExplorerModel",
            dependencies: [
                .product(name: "GATT", package: "GATT"),
                .product(name: "SkipFuse", package: "skip-fuse"),
                .product(name: "SkipModel", package: "skip-model")
            ],
            resources: [.process("Resources")]
        )
    ]
)
