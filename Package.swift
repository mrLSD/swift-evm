// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "evm-swift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EVM",
            targets: ["Interpreter"]),
        .library(
            name: "PrimitiveTypes",
            targets: ["PrimitiveTypes"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Interpreter",
            dependencies: ["PrimitiveTypes"],
            swiftSettings: [
                .define("DISABLE_TRACING")
            ]),
        .target(
            name: "PrimitiveTypes"),
        .testTarget(
            name: "InterpreterTests",
            dependencies: ["Interpreter", "PrimitiveTypes", "Quick", "Nimble"],
            swiftSettings: [
                .define("DISABLE_TRACING")
            ]),
        .testTarget(
            name: "PrimitiveTypesTests",
            dependencies: ["PrimitiveTypes", "Quick", "Nimble"])
    ])
