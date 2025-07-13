// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BluetoothExplorer",
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
            url: "https://github.com/PureSwift/Android.git", branch: "master"
        )
    ],
    targets: [
        .target(
            name: "BluetoothExplorerApp",
            dependencies: [
                .product(
                    name: "AndroidKit",
                    package: "Android"
                )
            ],
            path: "./app/src/main/swift",
            swiftSettings: [
              .swiftLanguageMode(.v5)
            ]
        )
    ]
)
