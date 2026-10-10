# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.3] - 2026-10-10

This release adds the Osaka `CLZ` opcode, moves Keccak-256 into a new `EVMCrypto` module with a trait-selected native implementation, introduces SwiftPM package traits, and hardens interpreter memory, gas, machine-state and tracing behavior. It requires Swift tools 6.1 and contains source-breaking changes; see **Breaking Changes**.

### Breaking Changes
- **Swift tools 6.1:** the manifest declares `swift-tools-version: 6.1` for package traits, so Swift 6.0 toolchains can no longer resolve the package ([#80]).
- **`Opcode.CLZ`:** the new case breaks exhaustive `switch` statements over `Opcode` that have no `default` ([#80]).
- **`Memory.ceil32(_:)` and `Memory.numWords(_:)`:** `ceil32(_:)` returns `Int?` and yields `nil` when rounding up overflows `Int`, instead of saturating to a capacity smaller than the requested end. Both functions trap on negative input, and `numWords(_:)` is exact up to `Int.max` instead of undercounting by one word near it ([#80]).

### Added
- **`CLZ` opcode (0x1E, EIP-7939):** active from Osaka; pushes the number of leading zero bits of the top stack item, 256 for zero, for `LOW` (5) gas. Earlier forks fail with `HardForkNotActive` before the stack or gas is checked ([#80]).
- **`EVMCrypto` module and product:** `Keccak256.hash(_:)` computes the EVM Keccak-256 digest (`0x01` padding, not SHA3-256) of an `UnsafeRawBufferPointer`. The buffer needs no alignment, may be empty with a `nil` base address, and is neither modified nor retained. CryptoSwift is the default backend; the `TinyKeccak` trait selects a native Keccak-f[1600] sponge that keeps its state in temporary storage without per-hash heap allocations. `Interpreter` uses `EVMCrypto` and no longer depends on CryptoSwift directly ([#80]).
- **Package traits:** `TinyKeccak`, `Tracing`, `TraceCallTrace`, `TraceGasCalculation`, `TraceStackInOut`, `TraceHideUnchanged`, `TraceHideMemory`, `TraceHideStack`, `TraceHideStorage`, `TraceStorageHexValue` and `TraceOpcodeHexValue` map to the existing compiler defines, and every `Trace...` trait also enables `Tracing`. The default trait set is empty, so the default build is unchanged, and legacy `-Xswiftc -D...` options still work ([#80]).
- **`U256.leadingZeroBitCount`:** counts leading zero bits on the stored limbs and returns 256 for zero ([#80]).

### Changed
- **Memory limit bounds allocation:** `Memory` checks the whole-word capacity against its limit before calling the allocator, for reads as well as writes, so memory never grows past the limit; a limit that is not a multiple of 32 is rounded down. An opcode whose expansion exceeds the limit ends with `OutOfGas` after charging the expansion and without allocating. Previously opcode expansion allocated without checking the limit, and only a following write reported a `MemoryOperation` limit error. With the default limit of `Int.max`, gas runs out long before the limit ([#80]).
- **Allocation failure is fatal:** when the host allocator fails after the gas and limit checks, a memory-expanding opcode ends with `.Fatal(.ReadMemory)` instead of `OutOfGas`, so a host failure is no longer reported as an ordinary EVM error. An embedding executor must abort the enclosing execution on a fatal exit ([#80]).
- **In-place memory access:** opcodes expand and charge a range first and then read or write it through precondition-checked accessors. `MSTORE` and `MSTORE8` write into the expanded range, `CODECOPY` and `CALLDATACOPY` copy with zero-fill, and `KECCAK256` passes the range to `Keccak256.hash` without copying it through `Memory.get`; only the CryptoSwift backend still copies it internally. The checked `set`, `copy` and `copyData` methods keep their own limit validation. Results of successful operations are unchanged ([#80]).
- **Allocation-free opcodes:** `SIGNEXTEND`, `BYTE`, `MSTORE8`, `ORIGIN`, `COINBASE` and the `EXP` gas calculation work on stored fields instead of building `BYTES` arrays. Results are unchanged ([#80]).
- **Shared instruction table:** opcode dispatch uses a static, immutable table of `@Sendable` functions shared by all machines, so creating a `Machine` no longer rebuilds 256 entries ([#80]).
- **Exact memory gas:** `GasCost.memoryGas(numWords:)` evaluates `3 * N + floor(N * N / 512)` with a full-width square and reports overflow only when the total does not fit in `UInt64`. It previously reported overflow from 2^32 words, as soon as `N * N` exceeded 64 bits, although the cost still fit. Both thresholds are far beyond any payable gas, so opcode results are unchanged ([#80]).
- **Documented contracts:** `Keccak256.hash(_:)` documents its buffer contract, `Memory` documents its two access tiers, `ExitFatal.ReadMemory` documents allocation failure, and the arithmetic handler comments state that a stack underflow or gas failure sets an error exit ([#80]).

### Fixed
- **Terminal machine state:** `step()` does nothing once the machine has exited, and `evalLoop()` preserves an existing exit reason. Previously `step()` executed the instruction at the program counter again, and `evalLoop()` reset the status to `.Continue`, so a second call re-ran the instruction that had exited and could replace the exit reason ([#80]).
- **Trace data:** each entry stores a snapshot of memory instead of a reference to the machine's live memory, which made every entry show the final memory. `afterEval` keeps the program counter of the executed opcode instead of the advanced one, and a new step discards the previous `afterEval`. With `TRACE_STACK_INOUT`, entries record stack inputs and outputs when `Trace.Config.stackInOut` is set, and the stack journal is cleared around each instruction so values pushed by the caller are not attributed to it ([#80]).

### Tests
- **Keccak-256 KAT corpus:** `EVMCryptoTests` checks every byte-aligned entry of the Keccak team's `ShortMsgKAT_256` (lengths 0–255) and `LongMsgKAT_256` (256–4288 bytes) at eight buffer alignments, all 100 `MonteCarlo_256` checkpoints, an empty buffer with a `nil` base address, and vectors published by tiny-keccak, alloy-primitives (including EIP-191) and CryptoSwift (including one million bytes). Under `TinyKeccak`, seeded messages are also compared with CryptoSwift. Fixtures keep the original format and record the source archive and its SHA-256; the one-GiB `ExtremelyLongMsgKAT_256` recipe runs only when `EVM_KECCAK_EXTREMELY_LONG_KAT=1` is set ([#80]).
- **`CLZ`:** activation in every fork before stack and gas checks, every leading-bit position and zero, exact gas, and a full stack ([#80]).
- **Memory:** rounded-capacity limits for every memory-expanding opcode, the last allocated byte against the next word, empty ranges with a zero limit, rejection before the allocator for limits and rounding overflow, in-place reads and writes at unaligned offsets, zero-filled copies, accessor precondition messages, and exact `ceil32`/`numWords` near `Int.max` ([#80]).
- **Allocation failures:** `MLOAD`, `MSTORE` and `LOG` end with `.Fatal(.ReadMemory)` on a failed `malloc` or `realloc` without changing memory or emitting logs, the fatal exit survives later `step()` and `evalLoop()` calls, and limit and gas failures never reach the allocator ([#80]).
- **Gas:** `memoryGas` against independently computed values around 2^32 words and at the true overflow boundary, and an `MLOAD` that needs 2^32 words failing before allocation ([#80]).
- **Machine state and tracing:** every exit reason and all observable state survive repeated `step()` and `evalLoop()` calls; tracing records historical memory, the executed program counter, gas and per-instruction stack changes, honors hiding and stack-journal settings, maps traits to the default configuration, and renders output ([#80]).
- **Opcodes and primitives:** `MSTORE8` stores only the low byte, `KECCAK256` hashes memory ranges with exact gas, and `U256.leadingZeroBitCount` is checked at all 256 bit positions with sparse and dense lower bits ([#80]).

### CI/Build
- **Trait matrix:** CI builds, lints and tests six configurations, CryptoSwift and `TinyKeccak` each without tracing, with `Tracing` and with every `Trace...` trait, and uploads coverage for each configuration under its own name ([#80]).
- **Manual Keccak workflow:** the **Keccak 1 GiB** workflow runs only through `workflow_dispatch`. It builds the tests in release, runs `Keccak256Spec` with the one-GiB vector for both backends, and fails unless that example actually ran ([#80]).
- **Documentation:** the README describes `EVMCrypto`, the package traits, the Swift 6.1 requirement, the manual workflow, and that the full test suite requires a debug build ([#80]).

## [0.6.2] - 2026-10-08

This release implements `LOG0`–`LOG4`, enforces hard-fork activation for `SHL`, `SHR`, `SAR` and `PUSH0`, reports oversized memory operands and jump destinations with the same errors as EELS, and fixes `MemoryState` reads and storage resets across nested substates. Custom `InterpreterHandler` conformers and code that matches `Machine.ExitError` cases need source changes; see **Breaking Changes**.

### Breaking Changes
- **New `InterpreterHandler` requirements:** conformers must implement `isStatic()`, which reports whether the current call forbids state changes, and `log(address:topics:data:)`, which appends a log to the current substate and must leave the logs unchanged when it returns a failure ([#78]).
- **`Machine.ExitError` cases:** `WriteInStaticContext` was added for state changes attempted in a static call ([#78]), and `IntOverflow` was removed ([#79]). Exhaustive `switch` statements over this `@frozen` enum must handle the new case; code that matched `IntOverflow` should match `OutOfGas` for memory operands or `InvalidJump` for jump destinations instead (see **Changed**).

### Added
- **`LOG0`–`LOG4` opcodes (0xA0–0xA4):** pass the executing contract's address, 0–4 topics as big-endian `H256` values in EVM order, and a copy of the memory range to `InterpreterHandler.log(address:topics:data:)`. Gas is `375 + 8 * size + 375 * topics` plus memory expansion, as specified by the Yellow Paper and EELS; a cost that does not fit in `UInt64` fails with `OutOfGas`. An empty range ignores the offset and does not expand memory. A static call fails with `WriteInStaticContext`, and a handler failure ends execution with the returned error ([#78]).

### Changed
- **Oversized memory operands fail with `OutOfGas`:** offsets and sizes that do not fit in `Int` for `MLOAD`, `MSTORE`, `MSTORE8`, `KECCAK256`, `CODECOPY`, `CALLDATACOPY`, `RETURN` and `REVERT` end execution with `OutOfGas`, because the memory expansion they require cannot be paid for; this matches EELS and revm. They previously ended with `IntOverflow` ([#79]).
- **Oversized jump destinations fail with `InvalidJump`:** `JUMP`, and `JUMPI` with a nonzero condition, treat a destination that does not fit in `Int` like any other invalid destination. They previously ended with `IntOverflow`. A `JUMPI` with a zero condition still ignores its destination ([#79]).

### Fixed
- **Hard-fork activation:** `SHL`, `SHR` and `SAR` (EIP-145) require Constantinople and `PUSH0` (EIP-3855) requires Shanghai. On earlier forks they fail with `HardForkNotActive` before the stack or gas is checked, as `REVERT` already does before Byzantium; previously they executed in every fork ([#79]).
- **Empty `RETURN` and `REVERT` output:** a zero length ignores the offset, as in EELS, and produces an empty return range without touching memory. Previously the offset was converted first, so an offset that did not fit in `Int` failed with `IntOverflow` ([#79]).
- **`MemoryState` reads:** `basic(address:)`, `code(address:)` and `storage(address:index:)` return the value known to the substate chain or the backend's value without recording it in the current substate. Previously a read cached the backend value like a write, which made it part of the substate and merged it into the parent on commit ([#79]).
- **Storage reset across commits:** committing a child substate keeps a storage reset made by an enclosing state. Previously a child that touched the account committed a copy with the reset flag cleared, replacing the parent's account, so later reads of untouched slots could return pre-reset backend values ([#79]).
- **Original storage after a reset:** `originalStorage(address:index:)` returns zero when the account's storage was reset in the current or any enclosing substate, instead of always returning the backend value ([#79]).
- **Stepping a new machine:** `step()` on a machine that has not started now starts it. Previously the status stayed `.NotStarted`, the program counter did not advance, and the next step executed the same instruction again ([#79]).

### Tests
- **`LOG0`–`LOG4`:** for every topic count, emitted address, data and topic order; empty data without inspecting the offset or expanding memory; exact memory expansion including the quadratic term; unaligned zero-padded slices; insufficient base, data and memory gas; missing arguments checked before consuming stack or gas; static calls; handler failures; a full stack; and availability in every hard fork. Further cases cover unrepresentable operands, gas overflow before allocation, allocation failures, event order and data snapshots, no double charge after `MSTORE`, refunds that cannot pay for logs, substate log retention through commit, revert and discard, and tracing. `GasCost.logCost` is checked at the last representable cost and on overflow ([#78]).
- **Fork activation:** `SHL`, `SHR`, `SAR` and `PUSH0` in every supported fork, with activation checked before stack and gas requirements, and `REVERT` activation at Byzantium before its stack check ([#79]).
- **Error classification:** oversized memory operands report `OutOfGas` across opcodes, copies from oversized source offsets are zero-filled, zero-length `CODECOPY` and `CALLDATACOPY` accept any offset, and oversized jump destinations fail only when the jump is taken ([#79]).
- **`RETURN` and `REVERT`:** empty output for every offset, including a `PUSH32` offset with the highest bit set, and exact nonempty slices across a word boundary ([#79]).
- **Stepping:** stepping a new machine executes each instruction once and matches `evalLoop`, preserves immediate exits and specific errors, starts before invoking the handler, and keeps instruction-controlled program-counter changes ([#79]).
- **`MemoryState`:** reads of existing and absent accounts stay out of the journal across committed substates, and zero or empty overrides are preserved. Reset cases cover a parent reset surviving a touched child's commit on every fork, post-reset writes through nested commits, parent writes cleared only by the child's own reset, restoration after a reverted or discarded inner reset, and zero original storage after local and ancestor resets ([#79]).

## [0.6.1] - 2026-10-03

### Added
- **`GAS` opcode (0x5A):** pushes the gas remaining after the instruction's own `BASE` cost of 2, as specified by the Yellow Paper and the EELS `gas_left` instruction. The handler lives in `SystemInstructions`, mirroring aurora-evm and revm. Previously no handler was registered and the opcode executed as `InvalidOpcode` ([#76]).

### Tests
- **`GAS` behavior:** remaining gas after the instruction cost, exact-limit and `OutOfGas` cases, full 64-bit values, per-step updates across a sequence, inclusion of prior opcode and memory-expansion costs, exclusion of refunds, the stack-overflow check before charging, and availability in every hard fork ([#76]).

## [0.6.0] - 2026-09-30

`PrimitiveTypes` now stores every value inline in fixed machine-word fields and implements only the arithmetic the EVM needs on each concrete type. This release contains source-breaking API changes; see **Breaking Changes** for migration notes. It also fixes wrong `DIV`, `MOD`, `SDIV`, `SMOD`, `ADDMOD` and `MULMOD` results on Apple OS versions without runtime `UInt128` support.

### Breaking Changes
- **`BasicAccount.nonce` is `UInt64`:** `BasicAccount.nonce` and `BasicAccount.init(balance:nonce:)` take `UInt64` instead of `U256`, matching the EIP-2681 nonce limit of 2^64 - 1. `incNonce()` uses checked arithmetic and traps at `UInt64.max`; `MemoryState.incNonce(address:)` still returns `.MaxNonce` before incrementing ([#70]).
- **Generic `BigUInt` operators removed:** the protocol extension no longer implements arithmetic (`+`, `-`, `*`, `+=`, `-=`, `*=`, `overflowAdd`, `overflowSub`, `overflowMul`, `mul`), ordering (`<`, `<=`, `>`, `>=`, `cmpLess(lhs:rhs:)`) or bitwise operators (`~`, `&`, `|`, `^`, `<<`, `>>`). Each concrete type keeps only what the EVM needs: `U256` retains all of them except `cmpLess(lhs:rhs:)`; `U128` keeps `+`, `*`, `overflowAdd` and `mul`; `U512` keeps `+`, `*`, `overflowAdd`, `mul` and ordering; `I256` keeps signed ordering, arithmetic `>>` and `&` ([#70]).
- **Division operators are protocol requirements:** `/`, `%`, `/=` and `%=` moved from `BigUInt` extension defaults to requirements, so generic code dispatches to the concrete type. All built-in types implement them; custom conformers must implement all four, for example by delegating to `divRem(divisor:)` ([#74]).
- **Custom conformers define their own basics:** `BigUInt` and `FixedArray` no longer provide a default `==`, and `FixedArray` no longer provides a default `isZero` or the `getMax`/`getZero` helpers ([#70]); on `BigUInt` those helpers are internal ([#74]). Implement `==` (or rely on synthesized `Equatable`), `isZero`, `MAX` and `ZERO` explicitly.
- **Generic shifts renamed:** `BigUInt.shiftLeft(_:)` and `shiftRight(_:)` are now `shiftLeftForBytes(_:)` and `shiftRightForBytes(_:)`. `U256` still provides `shiftLeft(_:)`, `shiftRight(_:)`, `<<` and `>>`; `I256.shiftRight(_:)` and `>>` remain the arithmetic shift ([#70]).
- **Division internals are no longer public:** the public `divModKnuth(v:n:m:)` was replaced by a private helper that works on limb arrays ([#72]); `divMod(_:)`, `divModWord(hi:lo:y:)`, `addSlice(a:from:b:to:)` and `carryAddSlice(carry:q_hat:a:from:b:to:)` became internal, and `subSlice(a:from:b:to:)` was removed ([#74]). Use `divRem(divisor:)` or the division operators.
- **`I256` behavior changed:** `&` uses two's-complement semantics, zero is always non-negative, and `shiftRight(_:)`/`>>` handle zero values and non-positive shifts differently; see **Fixed** ([#70]).
- **No transitive `Foundation`:** `PrimitiveTypes` no longer imports `Foundation`. Code that used Foundation APIs (for example `String(format:)` or `Error.localizedDescription`) only through that transitive import must import `Foundation` itself ([#70]).

### Added
- **Field initializers:** `U128(l0:h0:)`, `U256(l0:l1:h0:h1:)`, `U512(l0:l1:l2:l3:h0:h1:h2:h3:)` and `I256(l0:l1:h0:h1:signExtend:)` take little-endian limbs; `H160(l0:l1:l2:)` and `H256(l0:l1:l2:l3:)` take big-endian fields, with `l0` holding the first eight bytes. They build values without an intermediate array ([#70]).
- **EVM word conversions:** `U256(bigEndian:)` reads up to 32 big-endian bytes from an `UnsafeRawBufferPointer` without alignment requirements, padding shorter input on the left; `writeBigEndian(to:)` writes exactly 32 bytes to a raw buffer, also without alignment requirements; `U256(from: H256)` and `H256(from: U256)` convert between hashes and words in big-endian order; `U256(truncating: U512)` keeps the low 256 bits ([#74]).
- **Exact 256-bit product:** `U256.fullMul(_:)` returns the full 512-bit product as `U512`; `overflowMul(_:)` derives its low half and overflow flag from it ([#74]).
- **Hex encoding helpers:** public `hexEncode(_:uppercase:)`, `hexEncodeNoPad(_:uppercase:)` and `hexByteAscii(_:uppercase:)` provide hex encoding without `Foundation` ([#70]).

### Changed
- **Inline value storage:** `U128`, `U256`, `U512`, `I256`, `H160` and `H256` keep their value in fixed machine-word fields instead of a heap-allocated array, so stored values need no heap buffer and copying them involves no reference counting. Array-based paths still allocate: `BYTES` is now a computed view that builds a new array on every access, and generic helpers such as `init(from: UInt64)` on `U128`, `U512` and `I256` go through a temporary array; prefer field-based APIs on hot paths. `H160` and `H256` hashing is synthesized from the stored fields ([#70]).
- **Field-based operations:** concrete types implement their addition, subtraction, multiplication, comparison, bitwise and shift operators directly on stored fields, and `H160`↔`H256` conversions shuffle limbs without byte arrays ([#70]). `U256` also specializes `getInt`/`getUInt` and `fromBigEndian`/`toBigEndian` ([#70]), `init(from: UInt64)` ([#72]) and `saturatingInt` ([#74]) instead of going through `BYTES`.
- **Faster division:** Knuth's Algorithm D runs on limb arrays, converting each operand once instead of rebuilding values at every step, and corrects quotient digits with `multipliedFullWidth` instead of `U128` temporaries ([#72]); step D4 subtracts `q_hat * v` in a single fused multiply-subtract pass without a temporary product ([#73]). `U256` division returns early when the dividend is smaller than the divisor, divides by a single limb with four chained `dividingFullWidth` steps ([#72]) and recognizes a quotient of one with a single subtraction ([#73]).
- **Word division:** 128-by-64-bit division uses `UInt64.dividingFullWidth` on every platform; the `#available`-gated `DivModUtils`, with its `UInt128` path and bitwise fallback, was removed (see **Fixed**) ([#70]).
- **Opcode word I/O:** `MLOAD` and `MSTORE` read and write 32-byte words directly in memory; `PUSH1`–`PUSH32` and `CALLDATALOAD` decode straight from code and call data, still zero-padding truncated input on the right; `ADDRESS`, `CALLER`, the empty-input `KECCAK256` hash and stack `H256` conversions no longer build byte arrays. `MULMOD` computes the exact product with `U256.fullMul` (4×4 limbs) instead of multiplying zero-extended 8-limb `U512` operands, and `ADDMOD`/`MULMOD` narrow results with `U256(truncating:)`. Opcode results are unchanged ([#74]).
- **`SAR`:** delegates to the `I256` arithmetic shift and handles zero input and shifts of 256 or more up front; results are unchanged ([#70]).
- **Formatting without `Foundation`:** hex strings of `BigUInt` and `FixedArray` values, `Opcode.description` and trace stack dumps use the new helpers; output is unchanged ([#70]).
- **Checked invariants:** once `verifyStack` succeeds, opcode handlers force-unwrap stack reads instead of keeping unreachable `guard … else { return }` branches ([#70] for bitwise opcodes, [#72] for the rest), and `Memory` force-unwraps its buffer after a successful resize ([#73]). A broken invariant now traps instead of returning silently.
- **Documented contracts:** `I256` documents its magnitude-plus-sign representation, the two's-complement boundary of `fromU256`/`toU256`, and that `MAX` is the all-ones magnitude rather than the signed maximum 2^255 - 1; `BigUInt` integer-conversion documentation was clarified ([#74]).

### Fixed
- **Word division on older Apple OS versions:** where `UInt128` is unavailable at runtime (macOS < 15, iOS < 18, tvOS < 18, watchOS < 11, visionOS < 2), the bitwise fallback for 128-by-64-bit division dropped the high bit of the running remainder, so `DIV`, `MOD`, `SDIV`, `SMOD`, `ADDMOD` and `MULMOD` could return wrong results; for example, 2^127 / (2^64 - 1) yielded 0 instead of 2^63. Linux and newer Apple OS versions already used the correct `UInt128` path ([#70]).
- **`I256` compound division:** `/=` and `%=` resolved to the unsigned `BigUInt` defaults and dropped the sign (for example, `-6 /= 2` produced `3`); they now match `/` and `%` ([#72]).
- **`I256` division in generic code:** `/` and `%` called through a generic `BigUInt` context performed unsigned magnitude division; they now dispatch to the signed implementation ([#74]).
- **`I256` bitwise AND:** `&` now combines two's-complement representations and returns a correctly signed result; it previously ANDed magnitudes and always returned a non-negative value (for example, `-6 & -3` produced `2` instead of `-8`) ([#70]).
- **`I256` zero and arithmetic shift:** initializers normalize a zero magnitude to non-negative, so a negative zero can no longer be constructed; `shiftRight(_:)` and `>>` return zero for a zero value (negative zero produced `-1`) and return the value unchanged for a non-positive shift (a negative shift produced `0` or `-1`) ([#70]).
- **Strict hex parsing:** `fromString(hex:)` on every `BigUInt` and `FixedArray` type decoded byte pairs with `UInt8(_:radix:)`, which accepts a leading sign, so `"+f"` parsed as `0x0f` and `"-0"` as `0x00`. Only ASCII hex digits are accepted now; prefix, length, odd-length and empty-input rules are unchanged ([#74]).
- **Oversized shifts:** `U256` `<<`, `>>`, `shiftLeft(_:)` and `shiftRight(_:)` ([#70]) and the generic `shiftLeftForBytes(_:)` and `shiftRightForBytes(_:)` ([#72]) return zero for any shift at or beyond the type width; previously every shift larger than the width trapped with a range error. `SHL`, `SHR` and `SAR` already bounded the shift and were not affected.

### Tests
- **Division properties:** `U256` and `U512` quotients and remainders are checked for `a = q * d + r` and `r < d` against an independent base-256 reference, with seeded (SplitMix64) operands for every normalization shift, operand length and full-width case through generic and concrete paths ([#70], [#72]) and with deterministic limb-boundary, saturated-estimate and quotient-one/two cases ([#70], [#73]). Knuth add-back, `r_hat` overflow and double-correction cases assert exact results ([#70]). Word division is checked around every divisor bit boundary and against `UInt128` where the runtime provides it, including traps for a zero divisor and for `hi >= divisor` ([#70]).
- **Independent references:** `I256` division and remainder sign identities, `SAR` against a bit-level reference, two's-complement AND, canonical zero, and compound, optional, returned and generic-context division; `U128`, `U256` and `U512` multiplication, `fullMul` and `overflowMul` flags against an independent full product ([#70], [#72], [#74]).
- **Encoding and conversions:** strict hex parsing for every integer, address and hash type, exhaustive `hexDecodeByte` ASCII cases, the hex helpers, `H160`/`H256` limb packing and per-limb equality, and unaligned big-endian word reads and writes of every length and offset, including precondition failures ([#70], [#74]).
- **Opcode regressions:** `DIV`, `MOD`, `SDIV`, `SMOD`, `ADDMOD` and `MULMOD` with high-bit remainders, sign combinations and Knuth corrections; `SAR` boundaries; `SIGNEXTEND`; unaligned `MSTORE`/`MLOAD`; truncated `PUSH` immediates and `CALLDATALOAD` padding ([#70], [#72], [#73], [#74]).
- **Failure paths:** deterministic allocation failures through internal `Memory` allocation hooks (contents preserved, errors propagated, `MSTORE` stopping with `OutOfGas` after charging memory gas), the `BasicAccount.incNonce()` overflow trap, and `Stack.peekUInt` rejecting values wider than `UInt` without consuming the stack ([#70], [#72], [#73]).

### CI/Build
- **Toolchain:** CI uses the Swift toolchain bundled with the runner's default Xcode instead of `SwiftyLab/setup-swift` pinned to Swift 6.0 ([#70]).
- **Coverage gates:** the Codecov patch target rose from 50% to 100% and the project status is enabled at 100%, both with a zero threshold ([#74]); the obsolete `DivModUtils.swift` ignore entry was removed ([#70]).
- **SwiftLint:** the configuration follows Xcode SwiftFormat — `trailing_comma` is disabled, and `opening_brace` accepts multiline type headers, statement conditions and function signatures ([#74]).
- **Repository:** the local `docs/` directory is ignored by Git ([#74]).

## [0.5.26] - 2026-05-11

### Added
- **`H256.KECCAK_EMPTY` Constant:** Added the canonical Keccak-256 hash of the empty string (`""`) as a public static constant on `H256`. Useful for code-hash queries against accounts with no code without recomputing the digest at every call site ([#69]).
- **`BigUInt.saturatingInt`:** Added a saturating conversion to `Int` that returns `Int.max` when the value exceeds the host word size, instead of returning `nil`. Used by data-copy opcodes where any offset past `Int.max` is semantically equivalent to "past end of buffer" ([#69]).
- **`Stack.consume(count:)`:** Added a safe helper that removes the top N elements from the stack without returning them, with assertion-based underflow protection. Replaces idiomatic `_ = stackPop()` chains in instructions that have already validated their operands via `stackPeek` ([#69]).

### Changed
- **`CODECOPY` and `CALLDATACOPY` Stack Discipline:** Refactored both opcodes from the *pop-then-validate* pattern to the *peek-then-consume* pattern: operands are first read with `stackPeek(indexFromTop:)` and validated; the stack is mutated only via `stack.consume(count: 3)` after gas charging and memory resize succeed. This preserves the stack on failure paths, matching the pattern used by the rest of the instruction set ([#69]).
- **Code/Data Offset Handling:** `CODECOPY` and `CALLDATACOPY` now use `saturatingInt` for the source offset rather than `getIntOrFail`. Previously, an out-of-range offset caused a runtime fault; now it is correctly treated as "read past end of buffer", which `Memory.copyData` zero-fills as required by the Yellow Paper ([#69]).

### Fixed
- **Trace Stack-Out Ordering:** Fixed `Stack.consume(count:)` to record traced popped values in logical (least-significant-first) order rather than physical (top-down) order, so the `TRACE_STACK_INOUT` output matches the order produced by other instructions ([#69]).

### Tests
- **MachineStackTests:** Added a new test file (98 LOC) covering `consume(count:)` underflow safety, no-op behaviour with `count: 0`, and trace-output ordering ([#69]).
- **System Instructions:** Extended `KeccakTests`, `CallDataCopyTests`, and `CodeCopyTests` for the new peek/consume flow and saturating-offset behaviour ([#69]).
- **Primitive Types:** Added `saturatingInt` test cases to `H256Tests`, `I256Tests`, `U128Tests`, `U256Tests`, and `U512Tests` ([#69]).

## [0.5.25] - 2026-04-27

### Added
- **EIP-7702 Authorization:** Introduced public `Authorization` struct holding an `authority`, target `address`, `nonce`, and `isValid` flag, plus helpers for delegation-designator parsing — `Authorization.isDelegated(code:)`, `Authorization.getDelegatedAddress(_:)`, and `Authorization.delegationCode()` (encodes the canonical `0xef0100 ++ address` 23-byte sequence) ([#64]).
- **Account Models:** Replaced the previous single `Account.swift` with a richer `Accounts.swift` containing `BasicAccount` (saturating `addBalance`/`subBalance`, `incNonce`, default value) and `StateAccount` (basic + optional code + reset flag) ([#64]).
- **Transfer Type:** Added a public `Transfer` struct as the foundation for value-transfer semantics in future `CALL`-family opcodes ([#64]).
- **Hierarchical MemoryState:** Major extension of `MemoryState` with full nested-call substate support: `enter()` / `exitCommit()` / `exitRevert()` / `exitDiscard()`, swap-and-merge logic for `accounts`/`storages`/`tstorages`, recursive parent-chain queries (`knownAccount`, `knownStorage`, `isCold`, `isStorageCold`, `isDeleted`, `isCreated`), authority-target cache with parent traversal, plus `incNonce`, `setStorage`, `resetStorage`, `setCode`, and `isEmpty` helpers ([#64]).
- **Transient Storage State:** Added per-substate `tstorages` storage map for EIP-1153 transient storage (`TLOAD`/`TSTORE`) groundwork ([#64], [#66]).
- **Gas Helpers:** Extended `Gas` with stipend-merging logic used during substate exit-commit ([#64]).

### Changed
- **MemoryState Architecture:** `MemoryState` is now a hierarchical chain of substates linked via a `parent` reference, with O(1) state swap on enter/exit (Swift COW semantics on dictionaries/sets) and explicit cycle-breaking (`exited.parent = nil`) on exit. Lookups walk the parent chain until a known answer is found ([#64]).
- **Backend Integration:** Refined backend integration helpers (`getAccountAndTouch`, `basic(address:)`, etc.) to centralize cache-or-fetch logic between local substate and the host `Backend` ([#64]).

### Fixed
- **Substate Swap Logic:** Corrected an early issue in `MemoryState` swap ordering that surfaced during deeper nesting validation ([#64]).

### Tests
- **Foundational Coverage:** Added `AccountsTests`, `AuthorizationTests`, `LogsTests`, `TransferTests`, and the initial `MemoryStateTests`/`AccessedTests`/`MetadataTests` suites (~1000 LOC across the substate model) ([#64]).
- **Transient Storage Tests:** Added comprehensive `TStorage` tests covering set/get within a substate, propagation on commit, and isolation on revert ([#66]).
- **Authorization List Tests:** Added tests for the authority-target cache including parent-chain lookup, delegation-code parsing, and the address resolution flow used by EIP-7702 ([#66]).
- **Full-Coverage Pass:** Brought `MemoryState.swift` to 100% line coverage by exercising the previously-unhit branches: `isStorageCold` (current-state and recursive parent lookup), `recursiveIsCold` nil-accessed branch (Frontier hard fork before access lists existed), `exitCommit` merge of accounts/storages/tstorages with `reset` flag and conflict-resolution closures, `exitRevert` (state restoration plus gas-stipend merging), and `exitDiscard` (state restoration without gas merging) ([#67]).

## [0.5.24] - 2026-02-17

### Added
- **Memory State Management:** Introduced `MemoryState` class to handle hierarchical execution states, access tracking, and in-memory state mutations for nested executions ([#63]).
- **Backend Protocol:** Added a public `Backend` protocol providing a standardized interface for environment, block, account, and storage queries, including blob hash support ([#63]).
- **Primitive Types API:** Significantly expanded the public API surface for `U128`, `U256`, `I256`, `H160`, and `H256`. Added new constructors, overflow-aware arithmetic helpers, and hex parsing for `FixedArray` ([#62]).
- **Enhanced Error Reporting:** Expanded `Machine.ExitError` with granular runtime error types, including `StackUnderflow`, `StackOverflow`, `CallTooDeep`, `OutOfFund`, `IntOverflow`, and `InvalidRange` ([#63]).
- **State Models:** Added `BasicAccount` struct, `StateAccount` class, and a public `Log` struct to model account states and execution logs ([#63]).

### Changed
- **Instruction Validation:** Refactored the entire instruction set (Arithmetic, Bitwise, Control, Stack, System, and Host) to use the `verifyStack` pattern. Stack depth and gas requirements are now validated *before* execution to prevent inconsistent states ([#62]).
- **Interpreter Visibility:** Made `Executor`, `ExecutionState`, and their initializers `public` to allow external integration and custom execution flows ([#62]).
- **Arithmetic Semantics:** Updated `DIV`, `SDIV`, `MOD`, and `SMOD` instructions to explicitly return zero when the divisor is zero, aligning with EVM specifications ([#62]).
- **Memory & Gas Ordering:** Reordered memory resize and gas validation logic to ensure that state mutations (like `numWords` updates) only occur after successful validation ([#62]).
- **Host Interface:** Extended `InterpreterHandler` with mandatory methods for `balance`, `gasPrice`, `origin`, `chainId`, and `coinbase` to support the new backend architecture ([#63]).

### Fixed
- **Memory Safety:** Improved `memCpy` behavior in `copyData` with safer length computation and explicit zero-fill for out-of-range data ([#62]).

### Tests
- **Non-Destructive Testing:** Updated the test suite to use stack `peek` patterns instead of `pop`, allowing for better verification of the stack state after operations ([#62]).
- **Validation Coverage:** Added dedicated tests for stack underflow and overflow conditions across various opcodes ([#62]).

## [0.5.23] - 2026-01-19

### Added
- **CALLER Opcode:** Implemented the `CALLER` (0x33) opcode, allowing smart contracts to retrieve the address of the account that invoked the transaction or execution ([#59]).
- **Machine Status:** Introduced explicit `MachineStatus` enum (including `ExitSuccess`, `ExitFatal`, `ExitError`, `ExitRevert`) to strictly define the execution state and exit reasons ([#61]).
- **Stack Validation:** Added centralized `verifyStack(pop:push:)` methods to `MachineStack` for safer checking of underflow/overflow conditions before stack mutation ([#61]).
- **Memory Helpers:** Added optimized `memCpy` and `memSet` internal helpers for memory operations ([#61]).
- **Documentation:** Major overhaul of `README.md` and formatting updates to `CHANGELOG.md` ([#61]).

### Changed
- **Context Refactoring:** Renamed `Context` fields for greater clarity across the codebase ([#59]):
  - `target` → `targetAddress`
  - `sender` → `callerAddress`
  - `value` → `callValue`
- **Arithmetic Safety:** Completely refactored `ArithmeticInstructions` to use the new `verifyStack` pattern. Now, gas availability and stack requirements are validated *before* any operands are popped, preserving stack integrity in case of failure ([#61]).
- **Opcode Architecture:** Moved `ADDRESS` from Host to System instructions and standardized the implementation of `SELFBALANCE`, `ORIGIN`, and `COINBASE` within the Host instruction set ([#59]).
- **Jump Validation:** Updated `isValidJumpDestination` signature and logic to align with the new `MachineStatus` model ([#61]).
- **Visibility:** Made `HardFork` enum public to facilitate configuration from the host environment ([#61]).

### Tests
- **Caller Tests:** Added dedicated `CallerTests` suite covering standard execution, gas costs, and context propagation ([#59]).
- **Refactored Tests:** Updated `ArithmeticTests` and `MachineTests` to reflect the new `MachineStatus` error handling models and renamed Context fields ([#61]).
- **CLI Runner:** Added a CLI test-runner script for better test output formatting ([#61]).

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

## [0.5.9] - 2025-05-06

### Added
- **Flow Control Opcodes:** Implemented the core set of control flow instructions ensuring correct program counter manipulation:
  - `JUMP` (0x56): Unconditional jump to a destination.
  - `JUMPI` (0x57): Conditional jump based on stack value.
  - `JUMPDEST` (0x5B): Marks a valid destination for jumps.
  - `PC` (0x58): Get the value of the program counter before to the increment.
- **MSIZE:** Implemented `MSIZE` (0x59): Get the size of active memory in bytes.
- **Jump Validation:** Added `JumpTable` and valid destination verification logic to trap invalid jumps (jumping to non-JUMPDEST bytes or into immediate data) with `BadJumpDestination` error ([#43]).

### Tests
- **Coverage:** Added comprehensive tests for jump validity, infinite loops (with gas limits), and stack/memory interaction for `MSIZE` ([#43]).

## [0.5.8] - 2025-05-04

### Added
- **Stack Manipulation Opcodes:** Implemented a full suite of instructions for managing the EVM stack:
  - `PUSH0` through `PUSH32` (0x5F-0x7F): For pushing zero or immediate data from code to stack ([#42]).
  - `POP` (0x50): For removing the top item from the stack ([#42]).
  - `DUP1` through `DUP16` (0x80-0x8F): For duplicating stack elements ([#42]).
  - `SWAP1` through `SWAP16` (0x90-0x9F): For exchanging the top stack element with others ([#42]).
- **Memory Opcodes:** Implemented core instructions for volatile memory interaction:
  - `MLOAD` (0x51): Load a 32-byte word from memory onto the stack ([#42]).
  - `MSTORE` (0x52): Save a 32-byte word to memory ([#42]).
  - `MSTORE8` (0x53): Save a single byte to memory ([#42]).
- **Execution Lifecycle Opcodes:** Added instructions for halting and reverting execution:
  - `RETURN` (0xF3): Halts execution and returns a specified memory range as output ([#42]).
  - `REVERT` (0xFD): Halts execution, reverts state changes, and returns a memory range ([#42]).
  - `INVALID` (0xFE): Designated instruction to abort execution with an error ([#42]).
- **Memory Gas Calculation:** Implemented dynamic gas accounting for memory expansion, ensuring costs are correctly calculated based on the highest accessed memory word ([#42]).

### Changed
- **Memory Architecture:** Updated internal memory management to support byte-level addressing and automatic expansion during `MSTORE` and `MLOAD` operations ([#42]).

### Tests
- **Opcode Coverage:** Added exhaustive unit tests for all PUSH, DUP, and SWAP variations, covering both standard usage and stack boundary conditions ([#42]).
- **Memory Integrity:** Added tests for `MLOAD` and `MSTORE` to verify big-endian byte ordering and proper memory growth ([#42]).
- **Flow Control:** Added tests for `RETURN` and `REVERT` to ensure correct output data capture and execution status reporting ([#42]).

## [0.5.7] - 2025-04-28

### Added
- **CALLDATASIZE Opcode:** Implemented the `CALLDATASIZE` (0x36) opcode, returning the size in bytes of the input data sent with the current call ([#40]).
- **CALLDATALOAD Opcode:** Implemented the `CALLDATALOAD` (0x35) opcode, loading a 32-byte word from the input data starting at a given offset (zero-padded if the read extends past the end) ([#41]).
- **CALLDATACOPY Opcode:** Implemented the `CALLDATACOPY` (0x37) opcode, copying a range of input data into memory with proper memory expansion and gas accounting ([#41]).

### Tests
- **CALLDATASIZE Coverage:** Added unit tests for `CALLDATASIZE` covering empty calldata, normal sizes, and gas consumption (Base Gas: 2). Extended `CODESIZE` tests for parity ([#40]).
- **CALLDATALOAD/CALLDATACOPY Coverage:** Added unit tests covering offset boundaries, zero-padding past end-of-data, memory expansion costs, and stack discipline ([#41]).

## [0.5.6] - 2025-03-23

### Added
- **MSIZE Opcode:** Implemented the `MSIZE` (0x59) opcode, returning the active memory size in bytes (rounded up to the nearest 32-byte word) ([#39]).

### Tests
- **Coverage:** Added unit tests for `MSIZE` verifying memory expansion behavior, gas consumption (Base Gas: 2), and stack interactions ([#39]).

## [0.5.5] - 2025-03-16

### Added
- **MSTORE8 Opcode:** Implemented the `MSTORE8` (0x53) opcode for storing a single byte to memory at a given offset, taking only the least-significant byte of the 32-byte stack value ([#38]).

### Tests
- **Coverage:** Added unit tests for `MSTORE8` covering byte truncation behavior, memory expansion, gas accounting, and edge cases at memory boundaries ([#38]).

## [0.5.4] - 2025-03-15

### Added
- **MSTORE Opcode:** Implemented the `MSTORE` (0x52) opcode for saving a 32-byte word to memory at a given offset, including dynamic memory expansion and gas accounting ([#37]).

### Changed
- **Build Targets:** Updated minimum supported Apple OS versions in `Package.swift` to enable native `UInt128` support required for arithmetic primitives ([#37]).

### Tests
- **Coverage:** Added unit tests for `MSTORE` verifying big-endian byte ordering, memory growth on writes past current size, and gas cost correctness ([#37]).

## [0.5.3] - 2025-03-11

### Added
- **Hard Fork Configuration:** Extended the `HardFork` enum with additional fork-aware predicates and gas configuration entries, enabling fork-conditional behavior across the interpreter ([#36]).
- **EXP Gas Schedule:** Added EIP-160 (Spurious Dragon) aware gas pricing for the `EXP` opcode (per-byte cost increased from 10 to 50 gas after Spurious Dragon) ([#36]).
- **Documentation:** Updated `README.md` with hard-fork configuration details and additional usage notes ([#36]).

### Changed
- **Package Metadata:** Updated `Package.swift` configuration in support of broader hard-fork coverage ([#36]).

### Tests
- **Hard Fork Coverage:** Extended `HardForkTests` and `ExpTests` to verify pre-/post-Spurious Dragon EXP cost schedule and fork-conditional gating ([#36]).

## [0.5.2] - 2025-03-10

### Added
- **HardFork Enum:** Introduced a public `HardFork` enum covering all major Ethereum forks, allowing the `Machine` to gate fork-dependent behavior at runtime ([#34]).
- **MLOAD Opcode:** Implemented the `MLOAD` (0x51) opcode, loading a 32-byte word from memory onto the stack with automatic memory expansion ([#35]).

### Tests
- **HardFork Coverage:** Added a comprehensive `HardForkTests` suite verifying fork ordering and predicate accuracy ([#34]).
- **MLOAD Coverage:** Added unit tests for `MLOAD` covering big-endian byte order, memory expansion, gas accounting, and reads past current memory size ([#35]).

## [0.5.1] - 2025-03-02

### Added
- **CODECOPY Opcode:** Implemented the `CODECOPY` (0x39) opcode for copying a portion of the executing contract's code into memory, with proper memory expansion semantics ([#33]).
- **Memory Gas Costs:** Added formalized memory-expansion gas calculation logic in `Gas.swift` (linear `3·N` plus quadratic `N²/512` cost components) used by all memory-touching opcodes ([#33]).
- **`Memory.copyData`:** Added an internal helper for safe memory-from-buffer copy with offset clamping and zero-fill for out-of-range reads, used by `CODECOPY` and later by `CALLDATACOPY` ([#33]).

### Tests
- **CODECOPY Coverage:** Added unit tests for `CODECOPY` covering source-offset boundaries, target memory expansion, zero-fill of out-of-range bytes, and gas accounting accuracy ([#33]).
- **Gas Tests:** Added dedicated gas-cost tests for the new memory-expansion formula ([#33]).

## [0.5.0] - 2025-02-23

This is the first **0.5.x** baseline release, gathering a substantial Memory subsystem rewrite together with broad lint/CI hygiene work.

### Added
- **CI: SwiftLint Integration:** Added `.swiftlint.yml` configuration and wired SwiftLint into the GitHub Actions workflow to enforce code-style consistency on every push ([#32]).

### Changed
- **Memory Subsystem Refactor:** Major refactor of `Memory.swift` (~348-line delta): improved bounds validation, expansion accounting, and integration with the gas layer. Bitwise opcode implementations refactored in lock-step (~398-line delta in `Bitwise.swift`) for consistent stack/memory semantics ([#31]).
- **Stack Utilities & Gas Recording:** Refactored stack helpers and gas-record bookkeeping across the entire instruction set (Arithmetic, Bitwise, Control, Stack, System) — broad cleanup with ~340-line delta in `Arithmetic.swift` alone, standardizing the order of validate-then-pop-then-charge ([#32]).

### Tests
- **Memory & Stack Tests:** Reworked `MemoryTests` and `MachineTests` to align with the new memory bounds model; extended arithmetic tests for additional edge cases following the stack-utility refactor ([#31], [#32]).

## [0.4.0] - 2025-01-28

### Added
- **Control Flow Opcodes:** Implemented the core control-flow instruction set:
  - `STOP` (0x00) — halts execution successfully ([#30]).
  - `JUMP` (0x56) — unconditional jump to a destination popped from the stack ([#30]).
  - `JUMPI` (0x57) — conditional jump (jumps if the top-of-stack condition is non-zero) ([#30]).
  - `JUMPDEST` (0x5B) — marks valid jump destinations within bytecode ([#30]).
- **Jump Destination Validation:** Added `JumpTable` for indexing valid `JUMPDEST` positions in code, with verification that rejects jumps into the immediate-data region of `PUSH` instructions or onto non-`JUMPDEST` bytes (`BadJumpDestination` error) ([#30]).
- **Stack DUP Opcodes:** Implemented `DUP1` through `DUP16` (0x80–0x8F), duplicating the Nth stack item to the top with the canonical 3-gas (`VERYLOW`) cost ([#29]).
- **Stack SWAP Opcodes:** Implemented `SWAP1` through `SWAP16` (0x90–0x9F), exchanging the top of the stack with the (N+1)-th item ([#28]).

### Changed
- **Instruction Organization:** Moved `PC` opcode tests from `InstructionsTests/System/` to `InstructionsTests/Control/` to group flow-control tests together with the new `JUMP`/`JUMPI`/`STOP` tests ([#30]).
- **Gas Test Refactor:** Refactored gas-cost tests across Arithmetic and Bitwise instruction suites for consistency, in preparation for the broader gas-record cleanup that landed in v0.5.0 ([#29]).

### Tests
- **Stack Coverage:** Added `DupTests` covering all 16 `DUP` variants with stack-boundary checks ([#29]); added `SwapTests` covering all 16 `SWAP` variants ([#28]).
- **Control Coverage:** Added `JumpTests`, `JumpITests`, `StopTests`, and `JumpTableTests` for jump-validity checks, infinite-loop protection (gas-bounded), and PC manipulation ([#30]).

## [0.3.0] - 2025-01-19

### Added
- **Extended Arithmetic Opcodes:** Added the signed and modulus-based instruction family ([#20]):
  - `SDIV` (0x05) — signed integer division.
  - `SMOD` (0x07) — signed integer modulus.
  - `ADDMOD` (0x08) — `(a + b) mod n` using `U512` intermediate.
  - `MULMOD` (0x09) — `(a * b) mod n` using `U512` intermediate.
  - `EXP` (0x0A) — exponentiation with byte-length-aware gas cost.
  - `SIGNEXTEND` (0x0B) — sign-extend a value at a specified byte index.
- **Comparison Opcodes:** Implemented `LT` (0x10), `GT` (0x11), `SLT` (0x12), `SGT` (0x13), `EQ` (0x14), `ISZERO` (0x15) ([#21]).
- **Bitwise Logical Opcodes:** Implemented `AND` (0x16), `OR` (0x17), `XOR` (0x18), `NOT` (0x19), `BYTE` (0x1A) ([#21]).
- **Shift Opcodes:** Implemented `SHL` (0x1B), `SHR` (0x1C), `SAR` (0x1D), with correct semantics for shift amounts ≥ 256 ([#21]).
- **CODESIZE Opcode:** Implemented `CODESIZE` (0x38) returning the size of the executing contract code ([#23]).
- **PC Opcode:** Implemented `PC` (0x58) returning the current program counter prior to its post-instruction increment ([#24]).
- **POP Opcode:** Implemented `POP` (0x50) ([#25]).
- **PUSH Opcodes:** Implemented `PUSH0` (0x5F, EIP-3855) and `PUSH1`–`PUSH32` (0x60–0x7F) for pushing immediate values from bytecode to the stack, with proper PC advancement past the immediate-data region ([#27]).
- **Tracing Subsystem:** Added optional execution-tracing module (`Sources/Interpreter/Tracing/Trace.swift`, ~252 LOC) with conditional-compilation flags (`TRACING`, `TRACE_STACK_INOUT`). Provides per-instruction stack/memory/gas snapshots for debugging ([#26]).

### Changed
- **Stack Module Rename:** Renamed `Sources/Interpreter/Stack.swift` → `Sources/Interpreter/MachineStack.swift` (and the corresponding test file) to clarify its role as the EVM machine-stack abstraction ([#25]).

### Tests
- **Arithmetic Suite:** Added comprehensive tests for `SDIV`, `SREM`, `SIGNEXTEND`, `EXP`, `MUL`, and updated `SUB`/`DIV` (~907-line delta) ([#20]).
- **Bitwise Suite:** Added `AndTests`, `OrTests`, `XorTests`, `NotTests`, `ByteTests`, `ShlTests`, `ShrTests`, `SarTests`, `LtTests`, `GtTests`, `SltTests`, `SgtTests`, `EqTests`, `IsZeroTests`, `MachineTests` (~1247-line delta) ([#21]).
- **Bitwise Coverage Pass:** Added missing bitwise tests (extended `SLT`, `SGT`, `SHL`, `SHR`, `XOR` cases) and extended `I256Tests` (~1146-line delta) ([#22]).
- **System Coverage:** Added `CodeSizeTests` ([#23]), `PcTests` ([#24]), `PopTests` ([#25]).
- **Stack Coverage:** Added `Push0Tests` and `PushTests` covering PUSH0 + all PUSH1..PUSH32 variants ([#27]).

## [0.2.0] - 2024-11-04

### Added
- **U128 Integer Type:** Introduced `U128` as a 128-bit unsigned integer with full arithmetic and a comprehensive test suite (~441 LOC). Used internally as a primitive for multiply-accumulate carries and 128-by-64 division ([#15]).
- **U512 Integer Type:** Introduced `U512` as a 512-bit unsigned integer (used as the intermediate type for `ADDMOD`/`MULMOD`) with arithmetic and ~317 LOC of tests ([#18]).
- **I256 Signed Integer:** Introduced `I256` as a 256-bit signed integer with two's-complement representation, arithmetic, comparison, and arithmetic shift operations ([#18], [#19]).
- **Knuth Long Division:** Implemented Knuth Algorithm D (`divModKnuth`) for 256-bit division, with normalization and the `q_hat` correction loop, plus a fast-path `divModSmall` for divisors fitting in `UInt64` ([#15]).
- **`DivModUtils` Helper:** Added `DivModUtils.divModWord` (128-by-64 word division) used internally by Knuth's quotient-digit estimation ([#19]).
- **Bitwise Module:** Added a dedicated bitwise-operations file for `BigUInt` types — shift left/right, AND, OR, XOR, NOT — used by the upcoming Bitwise opcodes ([#18]).
- **DIV/MOD Opcodes:** Implemented `DIV` (0x04) and `MOD` (0x06) instructions with proper division-by-zero semantics (push zero, do not error) ([#17]).
- **CI: Code Coverage:** Added `.codecov.yml` configuration so coverage reports are published on each push ([#19]).

### Changed
- **Bitwise File Rename:** Corrected the typo `Bifwise.swift` → `Bitwise.swift` introduced in PR #18 ([#19]).
- **Arithmetic Helpers Refactor:** Refactored shared helpers in `PrimitiveTypes/Arithmetic.swift` for cleaner integration of Knuth division and `fullShr` utilities ([#17], [#19]).

### Tests
- **Division Fuzz:** Added a 100 000-iteration fuzz test (`FuzzDivTests`) validating `divRem` correctness against the platform-native `UInt128` ([#17], [#19]).
- **Division Edge Cases:** `DivRemTests` covering divide-by-zero (precondition), divisor > dividend, divisor = 1, multi-word divisors, and `qhat`-adjustment paths ([#15], [#17], [#18]).
- **U512 Coverage:** ~317 LOC of `U512Tests` covering construction, arithmetic, and bit manipulation ([#18]).
- **I256 Coverage:** ~534 LOC of `I256Tests` covering construction, signed arithmetic, comparison, sign-extend, and conversion to/from `U256` ([#18], [#19]).
- **Shift Tests:** Comprehensive shift-left/right test coverage with sign-handling cases for `I256` ([#18]).

## [0.1.0] - 2024-10-22

This is the **initial public release** of `swift-evm` — a Swift-native Ethereum Virtual Machine implementation. It establishes the entire foundation: primitive arithmetic types, the execution machine with status/eval loop, memory and stack subsystems, gas accounting, the opcode dispatch table, and the first wave of arithmetic and shift instructions.

### Added

#### Primitive Types (`PrimitiveTypes` module)
- **`BigUInt` Protocol:** Generic protocol covering arbitrary-width unsigned integers with `numberBytes`, `numberBase`, `BYTES` accessor, `MAX`/`ZERO` constants, hex parsing/encoding, big-endian/little-endian conversions, equality and comparison operators ([#2], [#3], [#10]).
- **`FixedArray` Protocol:** Companion protocol for fixed-size byte arrays (used by hash types) with hex parsing, equality, and zero/max helpers ([#3]).
- **`U256`:** 256-bit unsigned integer (4 × `UInt64` limbs) with full arithmetic, comparison, and bitwise operations ([#2], [#3], [#4], [#10]).
- **`H160`:** 20-byte fixed array representing Ethereum addresses ([#4]).
- **`H256`:** 32-byte fixed array representing hashes, with conversion helpers from/to `H160` ([#5]).
- **Arithmetic Primitives:** Reusable implementations of `overflowAdd`, `overflowSub`, and the multiply-accumulate (`mac`) primitive used across integer types ([#11], [#12]).
- **Shift Operations:** Full implementation of bit-level left/right shifts on `BigUInt` types with correct word/bit boundary handling, plus `U128` shift helpers ([#16]).

#### Interpreter (`Interpreter` module)
- **Opcode Table:** Complete `Opcodes` enum mapping all standard EVM opcodes (0x00–0xFF) with mnemonic names and per-opcode metadata ([#1], [#13], [#14]).
- **`Machine`:** Core EVM execution machine holding program counter, code/data buffers, memory, stack, gas, and an opcode-dispatch table built from function pointers ([#1], [#6], [#7], [#14]).
- **Machine Status & Eval Loop:** `MachineStatus` enum (`Continue`, `Stop`, `Exit*`), `step()` / `evalLoop()` execution control, and structured exit reasons ([#6], [#7]).
- **Memory Subsystem:** Initial `Memory` implementation with byte-addressable buffer, automatic expansion semantics, and integration with the gas layer ([#1], [#2], [#7], [#14]).
- **Stack Subsystem:** `Stack` type with `push`/`pop`/`peek`, the canonical 1024-element depth limit, and structured underflow/overflow errors ([#8]).
- **Gas Accounting:** `Gas` and `GasConstant` modules with `recordCost`, gas tracking, and the canonical EVM gas constants used by the instruction set ([#9], [#12], [#14]).
- **Arithmetic Instructions:**
  - `ADD` (0x01) ([#11]).
  - `MUL` (0x02) ([#13]).
  - `SUB` (0x03) ([#12]).
- **Instruction Modules:** Established `Sources/Interpreter/Instructions/` (Arithmetic, Bitwise) with the canonical pattern of *gas-charge → pop operands → execute → push result* ([#13], [#14]).

### Tests
- **PrimitiveTypes Coverage:** `U256Tests` (~140 LOC), `H160Tests` (~55 LOC), `H256Tests` (~101 LOC), and `CustomBigUIntTests` — BDD-style tests verifying the `BigUInt` protocol contract via a custom 128-bit conformance ([#3], [#4], [#5]).
- **Arithmetic Coverage:** Comprehensive opcode tests for `ADD`, `SUB`, `MUL`, with stack and gas verification — `AddTests` (~190 LOC), `SubTests` (~159 LOC), `MulTests` (~204 LOC), `MacTests` (~282 LOC) ([#11], [#12], [#13], [#14]).
- **Stack & Memory Coverage:** `StackTests` (~413 LOC) and initial `MemoryTests` covering push/pop, expansion, and gas accounting ([#8], [#14]).
- **Opcode Coverage:** `OpcodeTests` (~485 LOC) verifying the opcode table, gas costs, and dispatch correctness ([#10], [#13]).
- **Gas Coverage:** `GasTests` (~294 LOC) for `recordCost` accuracy and edge cases ([#12]).

### CI/Build
- **Swift Toolchain & CI:** Initial `Package.swift` configuration; CI pipeline (`.github/workflows/swift.yaml`) runs the unit-test suite on every push ([#1], [#10]).
- **Quick / Nimble:** Adopted [Quick](https://github.com/Quick/Quick) and [Nimble](https://github.com/Quick/Nimble) for BDD-style testing across the entire test suite ([#3]).
- **README:** Initial project README with architecture overview ([#10]).


<!-- Versions -->
[Unreleased]: https://github.com/mrLSD/swift-evm/compare/v0.6.3...HEAD
[0.6.3]: https://github.com/mrLSD/swift-evm/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/mrLSD/swift-evm/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/mrLSD/swift-evm/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/mrLSD/swift-evm/compare/v0.5.26...v0.6.0
[0.5.26]: https://github.com/mrLSD/swift-evm/compare/v0.5.25...v0.5.26
[0.5.25]: https://github.com/mrLSD/swift-evm/compare/v0.5.24...v0.5.25
[0.5.24]: https://github.com/mrLSD/swift-evm/compare/v0.5.23...v0.5.24
[0.5.23]: https://github.com/mrLSD/swift-evm/compare/v0.5.22...v0.5.23
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
[0.5.9]: https://github.com/mrLSD/swift-evm/compare/v0.5.8...v0.5.9
[0.5.8]: https://github.com/mrLSD/swift-evm/compare/v0.5.7...v0.5.8
[0.5.7]: https://github.com/mrLSD/swift-evm/compare/v0.5.6...v0.5.7
[0.5.6]: https://github.com/mrLSD/swift-evm/compare/v0.5.5...v0.5.6
[0.5.5]: https://github.com/mrLSD/swift-evm/compare/v0.5.4...v0.5.5
[0.5.4]: https://github.com/mrLSD/swift-evm/compare/v0.5.3...v0.5.4
[0.5.3]: https://github.com/mrLSD/swift-evm/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/mrLSD/swift-evm/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/mrLSD/swift-evm/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/mrLSD/swift-evm/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/mrLSD/swift-evm/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/mrLSD/swift-evm/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/mrLSD/swift-evm/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mrLSD/swift-evm/releases/tag/v0.1.0

<!-- PRs -->
[#80]: https://github.com/mrLSD/swift-evm/pull/80
[#79]: https://github.com/mrLSD/swift-evm/pull/79
[#78]: https://github.com/mrLSD/swift-evm/pull/78
[#76]: https://github.com/mrLSD/swift-evm/pull/76
[#74]: https://github.com/mrLSD/swift-evm/pull/74
[#73]: https://github.com/mrLSD/swift-evm/pull/73
[#72]: https://github.com/mrLSD/swift-evm/pull/72
[#70]: https://github.com/mrLSD/swift-evm/pull/70
[#69]: https://github.com/mrLSD/swift-evm/pull/69
[#67]: https://github.com/mrLSD/swift-evm/pull/67
[#66]: https://github.com/mrLSD/swift-evm/pull/66
[#64]: https://github.com/mrLSD/swift-evm/pull/64
[#63]: https://github.com/mrLSD/swift-evm/pull/63
[#62]: https://github.com/mrLSD/swift-evm/pull/62
[#61]: https://github.com/mrLSD/swift-evm/pull/61
[#59]: https://github.com/mrLSD/swift-evm/pull/59
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
[#43]: https://github.com/mrLSD/swift-evm/pull/43
[#42]: https://github.com/mrLSD/swift-evm/pull/42
[#41]: https://github.com/mrLSD/swift-evm/pull/41
[#40]: https://github.com/mrLSD/swift-evm/pull/40
[#39]: https://github.com/mrLSD/swift-evm/pull/39
[#38]: https://github.com/mrLSD/swift-evm/pull/38
[#37]: https://github.com/mrLSD/swift-evm/pull/37
[#36]: https://github.com/mrLSD/swift-evm/pull/36
[#35]: https://github.com/mrLSD/swift-evm/pull/35
[#34]: https://github.com/mrLSD/swift-evm/pull/34
[#33]: https://github.com/mrLSD/swift-evm/pull/33
[#32]: https://github.com/mrLSD/swift-evm/pull/32
[#31]: https://github.com/mrLSD/swift-evm/pull/31
[#30]: https://github.com/mrLSD/swift-evm/pull/30
[#29]: https://github.com/mrLSD/swift-evm/pull/29
[#28]: https://github.com/mrLSD/swift-evm/pull/28
[#27]: https://github.com/mrLSD/swift-evm/pull/27
[#26]: https://github.com/mrLSD/swift-evm/pull/26
[#25]: https://github.com/mrLSD/swift-evm/pull/25
[#24]: https://github.com/mrLSD/swift-evm/pull/24
[#23]: https://github.com/mrLSD/swift-evm/pull/23
[#22]: https://github.com/mrLSD/swift-evm/pull/22
[#21]: https://github.com/mrLSD/swift-evm/pull/21
[#20]: https://github.com/mrLSD/swift-evm/pull/20
[#19]: https://github.com/mrLSD/swift-evm/pull/19
[#18]: https://github.com/mrLSD/swift-evm/pull/18
[#17]: https://github.com/mrLSD/swift-evm/pull/17
[#16]: https://github.com/mrLSD/swift-evm/pull/16
[#15]: https://github.com/mrLSD/swift-evm/pull/15
[#14]: https://github.com/mrLSD/swift-evm/pull/14
[#13]: https://github.com/mrLSD/swift-evm/pull/13
[#12]: https://github.com/mrLSD/swift-evm/pull/12
[#11]: https://github.com/mrLSD/swift-evm/pull/11
[#10]: https://github.com/mrLSD/swift-evm/pull/10
[#9]: https://github.com/mrLSD/swift-evm/pull/9
[#8]: https://github.com/mrLSD/swift-evm/pull/8
[#7]: https://github.com/mrLSD/swift-evm/pull/7
[#6]: https://github.com/mrLSD/swift-evm/pull/6
[#5]: https://github.com/mrLSD/swift-evm/pull/5
[#4]: https://github.com/mrLSD/swift-evm/pull/4
[#3]: https://github.com/mrLSD/swift-evm/pull/3
[#2]: https://github.com/mrLSD/swift-evm/pull/2
[#1]: https://github.com/mrLSD/swift-evm/pull/1
