// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promises",
    products: [
        .library(name: "Promises", targets: ["Promises"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Promises",
            dependencies: []
        ),
        .target(
            name: "Run",
            dependencies: ["Promises"]
        ),
        .testTarget(
            name: "PromisesTests",
            dependencies: ["Promises"]
        )
    ]
)
