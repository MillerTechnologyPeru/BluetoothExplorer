// swift-tools-version: 5.6

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "BluetoothExplorer",
    platforms: [
        .iOS("15.2")
    ],
    products: [
        .iOSApplication(
            name: "BluetoothExplorer",
            targets: ["BluetoothExplorer"],
            bundleIdentifier: "com.pureswift.bluetooth-explorer",
            teamIdentifier: "4W79SG34MW",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .bluetoothAlways(purposeString: "Bluetooth is needed to scan for devices.")
            ],
            appCategory: .developerTools
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/GATT.git", .branch("master"))
    ],
    targets: [
        .executableTarget(
            name: "BluetoothExplorer",
            dependencies: [
                .product(name: "DarwinGATT", package: "gatt"),
                .product(name: "GATT", package: "gatt")
            ],
            path: "."
        )
    ]
)
