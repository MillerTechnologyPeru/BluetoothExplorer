// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "BluetoothExplorer",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BluetoothExplorer",
            type: .dynamic,
            targets: ["BluetoothExplorer"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Android.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/AndroidBluetooth.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "BluetoothExplorer",
            dependencies: [
                "Android",
                "AndroidBluetooth"
            ]
        )
    ]
)
