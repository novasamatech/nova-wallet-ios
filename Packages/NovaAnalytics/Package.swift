// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAnalytics",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAnalytics", targets: ["NovaAnalytics"])
    ],
    dependencies: [
        .package(path: "../NovaAppAttest"),
        .package(path: "../NovaOperationSupport"),
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.0.1"),
        .package(url: "https://github.com/novasamatech/Foundation-iOS", exact: "1.2.0"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.0.1")
    ],
    targets: [
        .target(
            name: "NovaAnalytics",
            dependencies: [
                "NovaAppAttest",
                "NovaOperationSupport",
                .product(name: "Operation-iOS", package: "Operation-iOS"),
                .product(name: "Keystore-iOS", package: "Keystore-iOS"),
                .product(name: "Foundation-iOS", package: "Foundation-iOS"),
                .product(name: "SDKLogger", package: "logger-ios")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NovaAnalyticsTests",
            dependencies: ["NovaAnalytics"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
