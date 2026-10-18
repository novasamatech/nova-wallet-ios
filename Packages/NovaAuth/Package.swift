// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAuth",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAuth", targets: ["NovaAuth"])
    ],
    dependencies: [
        .package(path: "../NovaOperationSupport"),
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")
    ],
    targets: [
        .target(
            name: "NovaAuth",
            dependencies: [
                "NovaOperationSupport",
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
