// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAuth",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAuth", targets: ["NovaAuth"])
    ],
    dependencies: [
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "3.1.0"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.1.0"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.1.0")
    ],
    targets: [
        .target(
            name: "NovaAuth",
            dependencies: [
                .product(name: "Operation-iOS", package: "Operation-iOS"),
                .product(name: "Keystore-iOS", package: "Keystore-iOS"),
                .product(name: "SDKLogger", package: "logger-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NovaAuthTests",
            dependencies: ["NovaAuth"],
            resources: [.process("Fixtures")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
