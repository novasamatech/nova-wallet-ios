// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAppAttest",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAppAttest", targets: ["NovaAppAttest"])
    ],
    dependencies: [
        .package(path: "../NovaOperationSupport"),
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")
    ],
    targets: [
        .target(
            name: "NovaAppAttest",
            dependencies: [
                "NovaOperationSupport",
                .product(name: "Operation-iOS", package: "Operation-iOS"),
                .product(name: "Keystore-iOS", package: "Keystore-iOS"),
                .product(name: "SDKLogger", package: "logger-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NovaAppAttestTests",
            dependencies: ["NovaAppAttest"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
