// swift-tools-version: 6.2
// Example BluetoothExplorer parser plugin, written in Embedded Swift and compiled to wasm32.
//
//   swift build -c release --swift-sdk swift-6.3.3-RELEASE_wasm-embedded --product GATTBodyFitness
//
import PackageDescription

let package = Package(
    name: "GATTBodyFitness",
    products: [
        .executable(name: "GATTBodyFitness", targets: ["GATTBodyFitness"])
    ],
    dependencies: [
        .package(path: "../../BLEPluginSDK")
    ],
    targets: [
        .executableTarget(
            name: "GATTBodyFitness",
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
