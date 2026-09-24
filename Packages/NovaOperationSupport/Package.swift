// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NovaOperationSupport",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NovaOperationSupport", targets: ["NovaOperationSupport"])
    ],
    dependencies: [
        .package(url: "https://github.com/novasamatech/Operation-iOS", exact: "2.1.2")
    ],
    targets: [
        .target(
            name: "NovaOperationSupport",
            dependencies: [
                .product(name: "Operation-iOS", package: "Operation-iOS")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
