[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift CI](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml/badge.svg)](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml)
[![codecov](https://codecov.io/gh/mrLSD/swift-evm/graph/badge.svg?token=1uc0niBI3c)](https://codecov.io/gh/mrLSD/swift-evm)
[![SwiftLint CI](https://img.shields.io/badge/SwiftLint-CI-blue.svg)](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml)
[![Swift versions badge](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FmrLSD%2Fswift-evm%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mrLSD/swift-evm)


<div align="center">
  <img src=".github/logo.png" alt="SwiftEVM" />

  <h1>mrLSD<code>/SwiftEVM</code></h1>
  <p><strong>A blazing fast 🚀, pure Swift implementation of the Ethereum Virtual Machine (EVM)</strong></p>
</div>

-----

**SwiftEVM** is a high-performance, open-source implementation of the Ethereum Virtual Machine, 
written entirely in **Swift**. Engineered to empower web3-developers, it enables seamless integration of EVM—execution into a diverse array of applications and platforms, including macOS, iOS, other Apple ecosystems, wasm32, Linux, and beyond.

Our focus is on:
- 🌐 **Opensource**: Fully open source, promoting transparency, community collaboration, and innovation.
- ⚡ **Speed & Performance**: Critical paths are highly optimized for blazing-fast execution.
- 🔒 **Security & Reliability**: 100% test coverage ensures predictable and robust behavior.
- 🔧 **Extensibility & Maintainability**: A modular architecture that facilitates ongoing improvements and customizations.

Modern development tools such as SwiftLint and swiftformat are part of our workflow, ensuring a clean, 
consistent codebase that is both developers-friendly.

---

## Current Status

- ✅ **EVM Machine**: Fully implemented
- ✅ **EVM Core**: ~90% complete
- ⏳ **EVM Runtime**: Under active development
- 🔜 **Ethereum Hard Forks**:
  - Berlin
  - London
  - Shanghai
  - Cancun
  - Prague
  - Osaka

## Integration & Future Plans

- **Blockchain Ecosystem**: Planned integration with [NEAR Protocol](https://near.org/) to broaden 
blockchain interoperability.
- **Key Environments**:
  - **Embedded Systems**: Bring blockchain capabilities to resource-constrained devices.
  - **WebAssembly (WASM)**: Run the EVM directly in WASM environments.
  - **Mobile & Desktop**: Seamlessly integrate decentralized functionalities into **iOS**, **macOS**, and other `Swift`-based platforms.

## Benefits

- **Pure Swift Implementation**: Leverage Swift’s performance and safety to integrate EVM directly into your projects.
- **Cross-Platform Compatibility**: Enjoy hassle-free deployment across multiple platforms.
- **Open Source**: Join a vibrant community—contribute, collaborate, and help shape the project’s future.
- **Customization & Extensibility**: Easily adapt and extend the EVM functionality to meet specific project needs.

## What’s included?

- 🔢 **`PrimitiveTypes` Library**: Implements high-performance math tailored specifically for Ethereum’s needs—offering
functionalities that generic libraries like `BigInt` and other general-purpose solutions can’t provide. 
It’s designed and optimized for the unique demands of the `EVM`.

- ⚙️ **`EVM` Library**: Contains the actual implementation of the **Ethereum Virtual Machine**, powering EVM bytecode execution seamlessly.

- 🔍 **EVM Tracing Support**: Provides robust tracing capabilities to assist developers in debugging and optimizing EVM execution.

## How to use

📱 Swift Support: Minimum supported version is `Swift 6`. 
This is due the new capabilities of `Swift 6`, including support for the `UInt128` type.

Use as dependency:
```swift
    dependencies: [
        .package(url: "https://github.com/mrLSD/swift-evm.git", from: "0.5.21")
    ]
```

## How to contribute

- ✅ All Tests Passing: Ensure that all tests run successfully.
- 📊 100% Test Coverage: Verify that your tests cover the entire codebase.
- 🛠️ SwiftFormat: Confirm that the `swiftformat` command completes.
- 🔧 SwiftLint: Confirm that the `swiftlint` command executes successfully.

### Unit tests

You can run:
- `swift test`
- `./Tests/cli-test-runner` - simple yet powerful tool to show tests errors
- `swift test | xcbeautify` - swift tests xcbeautify

### LICENSE: [MIT](LICENSE)
