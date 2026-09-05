// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Hermes",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "HermesCore", targets: ["HermesCore"]),
        .executable(name: "HermesPreview", targets: ["HermesPreview"]),
        .executable(name: "HermesApp", targets: ["HermesApp"])
    ],
    targets: [
        .target(name: "HermesCore"),
        .executableTarget(name: "HermesPreview", dependencies: ["HermesCore"]),
        .executableTarget(name: "HermesApp", dependencies: ["HermesCore"]),
        .testTarget(name: "HermesCoreTests", dependencies: ["HermesCore"])
    ],
    swiftLanguageModes: [.v6]
)
