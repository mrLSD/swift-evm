# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.22] - 2026-01-05

### Added
- **KECCAK256 Opcode:** Implemented full logic for the `SHA3` (KECCAK256) opcode, including gas cost calculation (base cost + dynamic word cost), memory expansion, and stack operations ([#56]).
- **Hex Encoding Helpers:** Added explicit helpers `encodeHexLower`, `encodeHexUpper`, and `hexString(uppercase:)` to `BigUInt` and `FixedArray` for flexible string representation ([#57]).
- **Error Handling:** Introduced public `HexStringError` enum to handle parsing failures (e.g., `invalidHexCharacter`, `invalidStringLength`) instead of runtime crashes ([#57]).
- **Prefix Support:** `BigUInt` hex parsing now supports `0x` and `0X` prefixes and handles empty strings by treating them as zero ([#57]).
- **Dependencies:** Added `CryptoSwift` (v1.9.0) dependency to support cryptographic hashing operations ([#56]).
- **Hardforks:** Added "Osaka" to the list of supported hard forks ([#56]).

### Changed
- **Hex Parsing Refactor:** Migrated hex string parsing from throwing fatal errors to returning `Result<Self, HexStringError>` across all primitive types (`BigUInt`, `U256`, `H160`, etc.) for safer error handling ([#57]).
- **String Output:** Standardized default hex string representations to use lowercase characters across the project ([#57]).
- **BigUInt Parsing:** Parsing logic now automatically pads odd-length hex strings for `BigUInt` (matching Rust implementation behavior), whereas `FixedArray` continues to enforce strict length requirements ([#57]).

### Fixed
- **Endianness Bug:** Fixed a critical issue in `BigUInt` hex parsing where input strings were incorrectly interpreted as little-endian bytes. They are now correctly parsed as big-endian ([#57]).

### Tests
- Added comprehensive test suite for `KECCAK256` covering gas accounting, memory limits, and hash correctness ([#56]).
- Added extensive tests for hex conversion edge cases including overflows, invalid characters, and prefix handling ([#57]).

## [0.5.21] - 2025-12-14

### Added
- **Tracing Enhancements:** Added `used` and `totalSpent` fields to `TraceGas` struct for granular gas tracking and introduced `TRACE_HIDE_MEMORY` configuration to conditionally suppress memory dumps in traces ([#55]).
- **CI/CD:** Added `.coderabbit.yaml` configuration for automated code reviews ([#55]).

### Changed
- **Memory Safety:** Strengthened memory bounds validation in `Memory.swift` by replacing arithmetic checks with remaining space calculations to better prevent overflow vulnerabilities ([#55]).
- **API Visibility:** Updated `Executor` class to be `public final` and restricted `STACK_LIMIT` access to `internal` ([#55]).
- **Documentation:** Corrected Ethereum hard fork block heights in comments and fixed various typos across opcode and primitive type documentation ([#55]).
- **Test Infrastructure:** Refactored `ReturnTests` to use per-test `Machine` instances instead of a shared static instance, eliminating `@MainActor` dependencies and improving test isolation ([#55]).

### Fixed
- **HardFork Logic:** Fixed `HardForkTests` where checking `isByzantium` was incorrectly validating against the Berlin fork logic ([#55]).
- **Test Descriptions:** Corrected misleading test descriptions for `ADDMOD`, `MULMOD`, `EXP`, and `MSIZE` to accurately reflect "OutOfGas" scenarios ([#55]).
- **Terminology:** Fixed endianness labeling in tests, correcting "Bit Endian" to "Big Endian" in `I256` and `U256` test suites ([#55]).

## [0.5.20] - 2025-12-01

### Changed
- **Memory Gas Calculation:** Refactored `memoryGas` logic in `Gas.swift` to explicitly separate linear (`3*N`) and quadratic (`N²/512`) costs with improved overflow protection ([#54]).
- **Test Suite Refactoring:** Removed shared `machineLowGas` static instances in favor of per-test `TestMachine` instantiation to ensure better test isolation and remove `@MainActor` dependencies ([#54]).
- **Gas Accounting:** Updated gas charging order for Arithmetic and Bitwise instructions to ensure consistency (charging gas after operand pops in specific cases) ([#54]).
- **Code Style:** Standardized stack push bindings in tests (replaced `let _ =` with `_ =`) ([#54]).
- **CI/CD:** Updated `.spi.yml` documentation targets and refined `.github/workflows/swift.yaml` to use dynamic test binary paths ([#54]).

### Fixed
- **SAR Opcode:** Fixed edge case handling for Shift Arithmetic Right (`SAR`) when shift amount is >= 255 ([#54]).

## [0.5.19] - 2025-08-24

### Added
- **COINBASE Opcode:** Implemented logic for the `COINBASE` (0x41) opcode, allowing the retrieval of the block's beneficiary address ([#53]).
- **Host Interface:** Updated the `InterpreterHandler` protocol to include `func coinbase() -> H160`, enabling the host environment to provide the miner/validator address ([#53]).
- **Documentation:** Added `.spi.yml` configuration to support automatic documentation generation on the Swift Package Index ([#53]).

### Tests
- **Coverage:** Added unit tests for `COINBASE` covering standard execution, out-of-gas scenarios, and stack overflow protections ([#53]).

## [0.5.18] - 2025-08-18

### Added
- **CHAINID Opcode:** Implemented logic for the `CHAINID` (0x46) opcode, allowing smart contracts to retrieve the current chain identifier ([#52]).
- **Host Interface:** Updated the `InterpreterHandler` protocol to include `var chainID: U256 { get }`, enabling the host environment to supply the correct chain configuration ([#52]).

### Tests
- **Coverage:** Added unit tests for the `CHAINID` opcode to verify correct return values and gas consumption (Base Gas: 2) ([#52]).

## [0.5.17] - 2025-08-11

### Added
- **ORIGIN Opcode:** Implemented logic for the `ORIGIN` (0x32) opcode, allowing smart contracts to retrieve the address of the account that originated the transaction (tx.origin) ([#51]).
- **Host Interface:** Updated the `InterpreterHandler` protocol to include `var origin: H160 { get }`, enabling the host environment to supply the transaction initiator's address ([#51]).

### Tests
- **Coverage:** Added unit tests for the `ORIGIN` opcode to verify correct return values and gas consumption (Base Gas: 2) ([#51]).

## [0.5.16] - 2025-07-21

### Added
- **GASPRICE Opcode:** Implemented logic for the `GASPRICE` (0x3A) opcode, allowing smart contracts to retrieve the gas price of the current transaction ([#50]).
- **Host Interface:** Updated the `InterpreterHandler` protocol to include `var gasPrice: U256 { get }`, enabling the host environment to supply the transaction gas price ([#50]).

### Tests
- **Coverage:** Added unit tests for the `GASPRICE` opcode to verify correct return values and gas consumption (Base Gas: 2) ([#50]).

## [0.5.15] - 2025-06-22

### Added
- **ADDRESS Opcode:** Implemented logic for the `ADDRESS` (0x30) opcode, allowing the executing code to retrieve its own address (the address of the account currently executing the contract) ([#49]).

### Tests
- **Coverage:** Added unit tests for the `ADDRESS` opcode to verify correct return values and gas consumption (Base Gas: 2) ([#49]).

## [0.5.14] - 2025-06-17

### Added
- **SELFBALANCE Opcode:** Implemented logic for the `SELFBALANCE` (0x47) opcode, allowing the contract to retrieve its own balance directly (available from the Istanbul hard fork) ([#48]).
- **Hardfork Support:** Logic ensures `SELFBALANCE` is only available when the active hard fork is Istanbul or later ([#48]).

### Tests
- **Coverage:** Added unit tests for `SELFBALANCE` covering gas costs (Low: 5), stack operations, and hard fork restrictions ([#48]).

## [0.5.13] - 2025-06-09

### Added
- **External State Opcodes:** Implemented a full suite of opcodes for interacting with external accounts, allowing the VM to query balances and code of other contracts:
  - `BALANCE` (0x31): Get balance of the given account.
  - `EXTCODESIZE` (0x3B): Get code size of an account.
  - `EXTCODECOPY` (0x3C): Copy an account's code to memory.
  - `EXTCODEHASH` (0x3F): Get the code hash of an account.
- **Host Interface:** Significantly expanded the `InterpreterHandler` protocol to support state access. New required methods include:
  - `balance(at address: H160) -> U256`
  - `codeSize(at address: H160) -> U256`
  - `codeHash(at address: H160) -> H256`
  - `codeCopy(at address: H160, range: Range<Int>) -> [UInt8]`
- **Gas Logic:** Added gas calculation logic for account access, including costs for accessing "cold" vs "warm" accounts (where applicable) and memory expansion costs for code copying ([#47]).

### Changed
- **State Architecture:** Refactored the internal execution model to delegate state queries (balance/code) to the host environment via the updated `InterpreterHandler` interface, enabling integration with complex state tries or mock environments ([#47]).

### Tests
- **Coverage:** Added extensive tests for the new opcodes, covering edge cases like non-existent accounts, memory boundary checks during code copy, and gas accounting accuracy ([#47]).

## [0.5.12] - 2025-06-07

### Added
- **WASM Support:** Added support for compiling and running the EVM on WebAssembly (wasm32) targets, enabling execution in browser environments ([#46]).
- **Cross-Platform Memory:** Implemented a unified memory management model that supports diverse build targets (macOS, Linux, Windows, WASM) without platform-specific conditional compilation ([#46]).

### Changed
- **Memory Refactor:** Completely refactored the internal `Memory` implementation to use safe, platform-agnostic buffer manipulations, removing dependencies on specific pointer widths or endianness that previously hindered WASM support ([#46]).
- **Build Targets:** Updated package configuration to explicitly support non-Apple platforms, verifying successful builds on Linux and Windows ([#46]).

## [0.5.11] - 2025-06-04

### Added
- **CALLVALUE Opcode:** Implemented logic for the `CALLVALUE` (0x34) opcode, allowing smart contracts to retrieve the value (in Wei) deposited by the instruction or transaction responsible for this execution ([#45]).
- **Runtime Context:** Updated the `Runtime` and `Machine` structures to correctly propagate transaction values (`msg.value`) into the execution context ([#45]).

### Changed
- **Runtime Refactor:** Refactored the internal Runtime initialization logic to support value transfers and context propagation, preparing the architecture for future `CALL` operations ([#45]).

### Tests
- **Coverage:** Added unit tests for `CALLVALUE` to verify it correctly places the transaction value onto the stack and charges the appropriate gas (Base Gas: 2) ([#45]).

## [0.5.10] - 2025-06-02

### Added
- **Runtime Environment:** Introduced the basic `Runtime` structure, laying the foundation for managing execution context, transactions, and block data ([#44]).

### Changed
- **Machine Architecture:** Refactored the core `Machine` type from a `struct` (value type) to a `class` (reference type). This change ensures a single mutable instance throughout execution, removing the need for `inout` passing and simplifying state management ([#44]).
- **Test Suite:** Updated all unit tests to align with the new reference semantics of the `Machine` class ([#44]).

<!-- Versions -->
[0.5.22]: https://github.com/mrLSD/swift-evm/compare/v0.5.21...v0.5.22
[0.5.21]: https://github.com/mrLSD/swift-evm/compare/v0.5.20...v0.5.21
[0.5.20]: https://github.com/mrLSD/swift-evm/compare/v0.5.19...v0.5.20
[0.5.19]: https://github.com/mrLSD/swift-evm/compare/v0.5.18...v0.5.19  
[0.5.18]: https://github.com/mrLSD/swift-evm/compare/v0.5.17...v0.5.18
[0.5.17]: https://github.com/mrLSD/swift-evm/compare/v0.5.16...v0.5.17
[0.5.16]: https://github.com/mrLSD/swift-evm/compare/v0.5.15...v0.5.16
[0.5.15]: https://github.com/mrLSD/swift-evm/compare/v0.5.14...v0.5.15
[0.5.14]: https://github.com/mrLSD/swift-evm/compare/v0.5.13...v0.5.14
[0.5.13]: https://github.com/mrLSD/swift-evm/compare/v0.5.12...v0.5.13
[0.5.12]: https://github.com/mrLSD/swift-evm/compare/v0.5.11...v0.5.12
[0.5.11]: https://github.com/mrLSD/swift-evm/compare/v0.5.10...v0.5.11
[0.5.10]: https://github.com/mrLSD/swift-evm/compare/v0.5.9...v0.5.10

<!-- PRs -->
[#57]: https://github.com/mrLSD/swift-evm/pull/57
[#56]: https://github.com/mrLSD/swift-evm/pull/56
[#55]: https://github.com/mrLSD/swift-evm/pull/55
[#54]: https://github.com/mrLSD/swift-evm/pull/54
[#53]: https://github.com/mrLSD/swift-evm/pull/53
[#52]: https://github.com/mrLSD/swift-evm/pull/52
[#51]: https://github.com/mrLSD/swift-evm/pull/51
[#50]: https://github.com/mrLSD/swift-evm/pull/50
[#49]: https://github.com/mrLSD/swift-evm/pull/49
[#48]: https://github.com/mrLSD/swift-evm/pull/48
[#47]: https://github.com/mrLSD/swift-evm/pull/47
[#46]: https://github.com/mrLSD/swift-evm/pull/46
[#45]: https://github.com/mrLSD/swift-evm/pull/45
[#44]: https://github.com/mrLSD/swift-evm/pull/44
