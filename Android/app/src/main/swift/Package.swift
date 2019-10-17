// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "BluetoothExplorer",
    products: [
        .library(
            name: "BluetoothExplorer",
            type: .dynamic,
            targets: ["BluetoothExplorerAndroid"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/AndroidBluetooth.git",
            .branch("master")
        ),
        .package(
            url: "https://github.com/PureSwift/AndroidUIKit.git",
            .branch("master")
        )
    ],
    targets: [
        .target(
            name: "BluetoothExplorerAndroid",
            dependencies: [
                "AndroidBluetooth",
                "AndroidUIKit"
            ],
            path: "Sources"
        )
    ]
)
