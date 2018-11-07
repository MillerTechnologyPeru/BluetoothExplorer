// swift-tools-version:4.1
import PackageDescription

let package = Package(
    name: "BluetoothExplorer",
    products: [
        .library(name: "BluetoothExplorer", type: .dynamic, targets: ["BluetoothExplorerAndroid"]),
    ],
    dependencies: [
        .package(url: "git@github.com:PureSwift/Android.git", .branch("master")),
        .package(url: "git@github.com:PureSwift/AndroidUIKit.git", .branch("master")),
        .package(url: "git@github.com:PureSwift/GATT.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "BluetoothExplorerAndroid",
            dependencies: ["GATT", "Android", "AndroidBluetooth", "AndroidUIKit"],
            path: "Sources"
        ),
    ]
)
