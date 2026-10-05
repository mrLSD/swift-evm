// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The TinyKeccak trait selects the native Keccak-256 implementation over CryptoSwift.
let cryptoSettings: [SwiftSetting] = [
    .define("TINY_KECCAK", .when(traits: ["TinyKeccak"]))
]

// TRACING explicitly enables tracing; DISABLE_TRACING records the default configuration.
let interpreterSettings: [SwiftSetting] = [
    .define("DISABLE_TRACING"),
    .define("TRACING", .when(traits: ["Tracing"])),
    .define("TRACE_CALL_TRACE", .when(traits: ["TraceCallTrace"])),
    .define("TRACE_GAS_CALC", .when(traits: ["TraceGasCalculation"])),
    .define("TRACE_STACK_INOUT", .when(traits: ["TraceStackInOut"])),
    .define("TRACE_HIDE_UNCHANGED", .when(traits: ["TraceHideUnchanged"])),
    .define("TRACE_HIDE_MEMORY", .when(traits: ["TraceHideMemory"])),
    .define("TRACE_HIDE_STACK", .when(traits: ["TraceHideStack"])),
    .define("TRACE_HIDE_STORAGE", .when(traits: ["TraceHideStorage"])),
    .define("TRACE_STORAGE_HEX_VALUE", .when(traits: ["TraceStorageHexValue"])),
    .define("TRACE_OPCODE_HEX_VALUE", .when(traits: ["TraceOpcodeHexValue"]))
]

let package = Package(
    name: "SwiftEVM",
    products: [
        .library(
            name: "EVM",
            targets: ["Interpreter"]
        ),
        .library(
            name: "EVMCrypto",
            targets: ["EVMCrypto"]
        ),
        .library(
            name: "PrimitiveTypes",
            targets: ["PrimitiveTypes"]
        )
    ],
    traits: [
        .default(enabledTraits: []),
        .trait(name: "TinyKeccak", description: "Use native Keccak-256 instead of CryptoSwift."),
        .trait(name: "Tracing", description: "Compile instruction tracing support."),
        .trait(name: "TraceCallTrace", description: "Enable the sub-call trace configuration.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceGasCalculation", description: "Enable the gas calculation trace configuration.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceStackInOut", description: "Collect per-instruction stack inputs and outputs.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceHideUnchanged", description: "Enable hiding unchanged trace data.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceHideMemory", description: "Hide memory in trace data.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceHideStack", description: "Hide the stack in trace data.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceHideStorage", description: "Enable hiding storage in trace data.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceStorageHexValue", description: "Enable hexadecimal storage formatting.", enabledTraits: ["Tracing"]),
        .trait(name: "TraceOpcodeHexValue", description: "Enable hexadecimal opcode formatting.", enabledTraits: ["Tracing"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.9.0"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0")
    ],
    targets: [
        .target(
            name: "Interpreter",
            dependencies: ["EVMCrypto", "PrimitiveTypes"],
            swiftSettings: interpreterSettings
        ),
        .target(
            name: "EVMCrypto",
            dependencies: ["CryptoSwift", "PrimitiveTypes"],
            swiftSettings: cryptoSettings
        ),
        .target(
            name: "PrimitiveTypes"),
        .testTarget(
            name: "InterpreterTests",
            dependencies: ["Interpreter", "PrimitiveTypes", "Quick", "Nimble"],
            swiftSettings: interpreterSettings
        ),
        .testTarget(
            name: "EVMCryptoTests",
            dependencies: ["EVMCrypto", "PrimitiveTypes", "CryptoSwift", "Quick", "Nimble"],
            resources: [.copy("Fixtures")],
            swiftSettings: cryptoSettings
        ),
        .testTarget(
            name: "PrimitiveTypesTests",
            dependencies: ["PrimitiveTypes", "Quick", "Nimble"]
        )
    ]
)
