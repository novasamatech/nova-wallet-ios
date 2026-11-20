// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaAnalytics",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaAnalytics", targets: ["NovaAnalytics"])
    ],
    dependencies: [
        .package(path: "../NovaAuth"),
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "3.1.0"),
        .package(url: "https://github.com/novasamatech/Keystore-iOS", exact: "1.1.0"),
        .package(url: "https://github.com/novasamatech/Foundation-iOS", exact: "1.5.0"),
        .package(url: "https://github.com/novasamatech/logger-ios", exact: "0.1.0")
    ],
    targets: [
        .target(
            name: "NovaAnalytics",
            dependencies: [
                "NovaAuth",
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
