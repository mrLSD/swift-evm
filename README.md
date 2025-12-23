[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift CI](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml/badge.svg)](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml)
[![codecov](https://codecov.io/gh/mrLSD/swift-evm/graph/badge.svg?token=1uc0niBI3c)](https://codecov.io/gh/mrLSD/swift-evm)
[![SwiftLint CI](https://img.shields.io/badge/SwiftLint-CI-blue.svg)](https://github.com/mrLSD/swift-evm/actions/workflows/swift.yaml)
[![Swift versions badge](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FmrLSD%2Fswift-evm%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mrLSD/swift-evm)


<div align="center">
  <img src=".github/logo.png" alt="SwiftEVM" />

  <h1>mrLSD<code>/SwiftEVM</code></h1>
  <p><strong>Portable, compliant, and high-performance pure Swift implementation of the Ethereum Virtual Machine (EVM)</strong></p>
</div>

-----

**SwiftEVM** is a modular EVM implementation  for the Ethereum protocol, written in pure Swift. It is designed for low-overhead 
integration into blockchain nodes, embedded systems, and Layer-2 solutions requiring deterministic EVM bytecode execution.

Unlike general-purpose wrappers, SwiftEVM offers a ground-up implementation of the **Yellow Paper** specifications, optimizing 
critical paths (dispatch loop, stack operations, and memory expansion) for Apple Silicon and other architectures.

### 📦 Swift Package Index
The project is indexed and verified on the Swift Package Index. You can view detailed build compatibility reports across platforms 
and generated documentation here:

[<img src="https://img.shields.io/badge/View_on-Swift_Package_Index-F05138?logo=swift&logoColor=white" alt="Swift Package Index" />](https://swiftpackageindex.com/mrLSD/swift-evm)

---

## Key Features

*   **Yellow Paper Compliant:** Strict adherence to Ethereum protocol specifications.
*   **Zero-Copy Architecture:** Optimized memory handling to minimize ARC overhead in hot execution paths.
*   **Platform Agnostic:** Runs natively on **macOS**, **iOS**, **Linux**, and **WebAssembly (wasm32)** and many others.
*.  **Uncompromising Reliability:** The codebase maintains **100% unit test coverage**. Every opcode, edge case, and gas calculation path is rigorously tested, ensuring production-grade stability and correctness rarely seen in early-stage implementations.
*   **Deterministic Execution:** 100% reproducible state transitions.
*   **Modular Design:** Decoupled components (Gasometer, Stack, Memory, Interpreter) allowing for custom extensions and instrumentation.

## Architecture

SwiftEVM is composed of specialized modules to ensure performance and correctness:

### 1. `PrimitiveTypes` (Arithmetic Core)
A specialized math library tailored for the EVM's 256-bit word size.
*   **Why not BigInt?** Generic BigInt libraries introduce overhead for dynamic allocation and do not natively handle EVM-specific behaviors (e.g., specific overflow wrapping, two's complement representation for `SDIV`/`SMOD`).
*   **UInt128 Support:** Leverages Swift 6 native `UInt128` for optimized high-precision calculations.

### 2. `EVM` (Core Execution)
The heart of the virtual machine.
*   **Interpreter:** Optimized opcode dispatch loop.
*   **Stack:** Fixed-size, high-performance LIFO structure with boundary safety checks.
*   **Memory:** Dynamic linear memory with gas-metered expansion logic.
*   **Gasometer:** Exact gas accounting for opcodes, intrinsic costs, and memory expansion.

### 3. `Tracing`
Granular execution tracing for debugging and state analysis. Supports standard JSON-RPC trace formats and custom hooks for indexers.

---

## Implementation Status & Roadmap

The project follows the latest Ethereum specification upgrades.

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Machine State** | ✅ Complete | Stack, Memory, Context, Gas |
| **Opcode Logic** | ✅ Complete | Arithmetic, Bitwise, Control Flow, System |
| **Precompiles** | 🔄 In Progress | ECRecover, SHA256, RIPEMD160, Identity etc. |
| **Runtime** | 🛠 Active Dev | Transaction context, Block environment |
| **zkEVM** | 🔜 Planned | Guest program, Block valudation & execution |

### Compliance & Verification
*  ✅ **Unit Testing:** 100% Code Coverage enforced by CI and CodeCov.
*  🔜 **Ethereum State Tests:** Planned full integration with the official Ethereum Test Suite (execution-spec-tests) to guarantee pixel-perfect consensus compatibility.


### Hard Fork Support
Targeting compliance with the following upgrades:
*   ✅ **Berlin**
*   ✅ **London**
*   ✅ **Shanghai**
*   ✅ **Cancun**
*   🔜 **Prague / Osaka** (*Planned*)

---

## Integration

### Requirements
*   **Swift 6.0+** (Required for `UInt128` and concurrency features).
*   **OS:** macOS 14+, iOS 17+, Ubuntu 22.04+, or any environment supporting Swift 6.

### Swift Package Manager
Add SwiftEVM to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/mrLSD/swift-evm.git", from: "0.5.21")
]
```

## Contributing

We welcome contributions from EVM experts and systems engineers. To maintain the integrity of the consensus engine, we enforce strict quality gates:

1.  **100% Test Coverage:** No code merges without full unit test coverage. Edge cases must be proven.
2.  **Linting:** Code must pass `swiftlint` and be formatted via `swiftformat`.
3.  **Performance:** PRs affecting the hot loop must demonstrate no regression in benchmarks.

### Development Environment

```bash
# Run test suite
swift test

# Run tests with prettified output
swift test | xcbeautify

# Check coverage (requires llvm-cov)
./Scripts/coverage.sh
```

---

## License

SwiftEVM is released under the [MIT License](LICENSE).
