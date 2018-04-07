// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Promises",
    products: [
        .library(name: "PromisesCore", targets: ["PromisesCore"]),
        .library(name: "PromisesExt", targets: ["PromisesExt"]),
    ],
    dependencies: [
         .package(url: "https://github.com/dmcyk/Atomic", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "PromisesCore",
            dependencies: ["Atomic"]
        ),
        .target(
            name: "PromisesExt",
            dependencies: ["Atomic"]
        )
    ]
)
