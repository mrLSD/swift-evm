// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftEVM",
    products: [
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
