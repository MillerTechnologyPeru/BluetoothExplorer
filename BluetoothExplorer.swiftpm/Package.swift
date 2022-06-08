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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/GATT.git", "3.0.3"..<"4.0.0"),
        .package(url: "https://github.com/PureSwift/Bluetooth.git", "6.0.4"..<"7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "BluetoothExplorer",
            dependencies: [
                .product(name: "GATT", package: "GATT"),
                .product(name: "DarwinGATT", package: "GATT"),
                .product(name: "Bluetooth", package: "Bluetooth")
            ],
            path: "."
        )
    ]
)
