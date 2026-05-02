import Foundation

/// One-stop grep target for the things this port stubs.
///
/// Every entry below points to the file owning the seam, so reviewers can find the
/// actual TODO header without searching the whole tree. Run `swift run EthereumSpecTests
/// state <fixtures>` and you'll see each test routed through one of these stubs and
/// reported as **skipped** (never as silently passed).
///
/// 1. **Transactor** — `Transact/Transactor.swift`
///    `transact_call` / `transact_create`: intrinsic gas, fee withdrawal, refund, access-list
///    seeding (EIP-2929), EIP-7702 authorization processing, EIP-4844 blob accounting,
///    sub-call frame management. Throws `TransactorError.notImplemented` from both entry
///    points. Every state test routes through this and is currently skipped here.
///
/// 2. **Precompiles** — `Runner/PrecompileRegistry.swift`
///    Per-fork registry (ECRECOVER, SHA256, RIPEMD160, IDENTITY, MODEXP, BN256_*,
///    BLAKE2F, KZG, BLS12-381 suite) is documented but `lookup(...)` returns `nil`.
///    No precompile is callable.
///
/// 3. **secp256k1 ECDSA recovery** — `Models/Eip7702.swift`
///    `SignedAuthorization.recoverAddress()` throws. Needed for both the EIP-7702
///    authorization-list pre-processing and the ECRECOVER precompile.
///
/// 4. **State-root MPT** — `Verification/StateRootHasher.swift`
///    The Rust harness uses a real Secure Patricia Merkle Trie root via
///    `ethereum::util::sec_trie_root`. Swift implementation pending. RLP/keccak layers
///    are real and tested. `compute(...)` throws `notImplemented`.
///
/// 5. **KZG (EIP-4844 blob verify)** — `Runner/PrecompileRegistry.swift` (entry 7)
///    `0x0a` precompile. Requires `c-kzg` or a Swift KZG implementation.
///
/// 6. **BLS12-381 (Prague)** — `Runner/PrecompileRegistry.swift` (entry 8)
///    `0x0b..0x11` suite. Requires `blst` or a Swift BLS implementation.
///
/// 7. **Sub-call frames in `Machine`** — `Sources/Interpreter/Machine.swift`
///    The existing Swift `Machine` is a single-frame interpreter. CALL/CALLCODE/
///    DELEGATECALL/STATICCALL/CREATE/CREATE2 opcodes are not in `instructionsEvalTable`,
///    so any test that exercises them currently exits with `InvalidOpcode` and is
///    reported as **skipped** by `VMRunner`. Out of scope for this port; tracked here
///    so future work can link back to a single inventory.
///
/// 8. **State-mutating opcodes** — `Sources/Interpreter/Machine.swift`
///    Same situation: SLOAD, SSTORE, TLOAD, TSTORE, LOG0..LOG4 are not dispatched.
///    The `MemoryState` class (which models world state) exists but no opcode writes
///    through it. Out of scope; tracked.
///
/// 9. **Caller derivation from `secret_key`** — `Runner/StateRunner.swift` line ~70
///    Rust derives the caller via secp256k1 `pubkey_from_secret`. Swift falls back to
///    the `sender` field; tests with only `secret_key` are skipped.
///
/// All of the above are deliberately left as seams so the port can ship today
/// (CLI walks, decodes, runs the subset of VM tests the existing `Machine` supports)
/// without silently misreporting state-test results.
enum STUBS {
    // intentionally empty; this file exists for documentation only.
}
