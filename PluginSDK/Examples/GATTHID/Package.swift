// swift-tools-version: 6.2
// Example BluetoothExplorer parser plugin, written in Embedded Swift and compiled to wasm32.
//
//   swift build -c release --swift-sdk swift-6.3.3-RELEASE_wasm-embedded --product GATTHID
//
import PackageDescription

let package = Package(
    name: "GATTHID",
    products: [
        .executable(name: "GATTHID", targets: ["GATTHID"])
    ],
    dependencies: [
        .package(path: "../../BLEPluginSDK")
    ],
    targets: [
        .executableTarget(
            name: "GATTHID",
            dependencies: [
                .product(name: "BLEPluginSDK", package: "BLEPluginSDK")
            ],
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .unsafeFlags(["-wmo"])
            ],
            linkerSettings: [
                // Reactor model: no main(); the host calls _initialize then the exports.
                .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"])
            ]
        )
    ]
)
