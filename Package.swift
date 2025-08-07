// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaPaySDKPackage",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NovaPaySDKPackage",
            targets: ["NovaPaySDKPackage"])
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NovaPaySDKPackage",
            dependencies: [
                .target(name: "NovaPaySDKFramework"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "NovaPaySDKPackageTests",
            dependencies: ["NovaPaySDKPackage"]),
        .binaryTarget(name: "NovaPaySDKFramework",
                      path: "./Sources/NovaPaySDKFramework.xcframework")
    ]
)
