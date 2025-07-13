// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "bluetooth-explorer-android",
    platforms: [
      .macOS(.v15),
    ],
    products: [
        .library(
            name: "BluetoothExplorerApp",
            type: .dynamic,
            targets: ["BluetoothExplorerApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Android.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/GATT.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "BluetoothExplorerApp",
            dependencies: [
                .product(
                    name: "AndroidKit",
                    package: "Android"
                ),
                "BluetoothExplorerModel"
            ],
            path: "./app/src/main/swift/app",
            swiftSettings: [
              .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "BluetoothExplorerModel",
            dependencies: [
                .product(
                    name: "GATT",
                    package: "GATT"
                )
            ],
            swiftSettings: [
              .swiftLanguageMode(.v5)
            ]
        )
    ]
)
