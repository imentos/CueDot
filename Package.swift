// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CueDot",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CueDot",
            targets: ["CueDot"]
        ),
    ],
    dependencies: [
        // Add dependencies here as needed
    ],
    targets: [
        .target(
            name: "CueDot",
            dependencies: [],
            path: "CueDot"
        ),
        .testTarget(
            name: "CueDotTests",
            dependencies: ["CueDot"],
            path: "Tests"
        ),
    ]
)