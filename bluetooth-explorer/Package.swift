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
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "BluetoothExplorer", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui")
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
