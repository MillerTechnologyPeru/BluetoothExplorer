// swift-tools-version: 6.2
// Guest-side SDK for authoring BluetoothExplorer parser plugins in Embedded Swift.
// Built for wasm32 with the `swift-<version>_wasm-embedded` Swift SDK; never part of the app build.
import PackageDescription

let package = Package(
    name: "BLEPluginSDK",
    products: [
        .library(name: "BLEPluginSDK", targets: ["BLEPluginSDK"])
    ],
    targets: [
        .target(
            name: "BLEPluginSDK",
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .unsafeFlags(["-wmo"])
            ]
        )
    ]
)
