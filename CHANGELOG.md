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

## [0.5.20] - 2025-11-30

### Changed
- **Memory Gas Calculation:** Refactored `memoryGas` logic in `Gas.swift` to explicitly separate linear (`3*N`) and quadratic (`N²/512`) costs with improved overflow protection ([#54]).
- **Test Suite Refactoring:** Removed shared `machineLowGas` static instances in favor of per-test `TestMachine` instantiation to ensure better test isolation and remove `@MainActor` dependencies ([#54]).
- **Gas Accounting:** Updated gas charging order for Arithmetic and Bitwise instructions to ensure consistency (charging gas after operand pops in specific cases) ([#54]).
- **Code Style:** Standardized stack push bindings in tests (replaced `let _ =` with `_ =`) ([#54]).
- **CI/CD:** Updated `.spi.yml` documentation targets and refined `.github/workflows/swift.yaml` to use dynamic test binary paths ([#54]).

### Fixed
- **SAR Opcode:** Fixed edge case handling for Shift Arithmetic Right (`SAR`) when shift amount is >= 255 ([#54]).

<!-- Versions -->
[0.5.22]: https://github.com/mrLSD/swift-evm/compare/v0.5.21...v0.5.22
[0.5.21]: https://github.com/mrLSD/swift-evm/compare/v0.5.20...v0.5.21
[0.5.20]: https://github.com/mrLSD/swift-evm/compare/v0.5.19...v0.5.20

<!-- PRs -->
[#57]: https://github.com/mrLSD/swift-evm/pull/57
[#56]: https://github.com/mrLSD/swift-evm/pull/56
[#55]: https://github.com/mrLSD/swift-evm/pull/55
[#54]: https://github.com/mrLSD/swift-evm/pull/54
