import Foundation
import PrimitiveTypes

/// Per-fork precompile dispatch.
///
/// **Status: stubbed.** Returns `nil` from every `lookup` — no precompile address
/// is callable. The Swift `Interpreter` does not currently have any precompile
/// implementations and `Transactor` (Phase 9 seam) does not yet route through this
/// registry. When the transactor lands, it should call `PrecompileRegistry.lookup`
/// before dispatching to the EVM bytecode.
///
/// Mirrors `aurora-evm::evm-tests::precompiles::Precompiles`. Per-fork TODO lists
/// (precompile addresses to implement) are below; each block is one column-aligned
/// line so it's a clean grep target.
///
/// Mapping reference: https://www.evm.codes/precompiled
enum PrecompileRegistry {
    /// Outcome of a precompile call. None of these variants are produced today.
    enum Outcome: Sendable {
        case success(returnData: [UInt8], gasUsed: UInt64)
        case failure(reason: String)
    }

    /// Look up the precompile at `address` for `spec`. Returns `nil` if no precompile is
    /// registered at that address for that fork.
    ///
    /// TODO: replace stub with real dispatch. Per-fork registry below.
    static func lookup(address: H160, spec: Spec) -> ((_ input: [UInt8], _ gasLimit: UInt64) -> Outcome)? {
        // The address space for precompiles is `0x000…0001` through `0x000…0011` (Prague).
        // We expose the per-spec sets as static metadata only — the call sites will use the
        // table to inject correct gas costs and returned bytes once an implementation lands.
        _ = address
        _ = spec
        return nil
    }

    // MARK: - Per-fork address tables (informational; not yet hooked up to dispatch)

    // Frontier..Homestead (registered at activation):
    //   0x01 ECRECOVER     - secp256k1 ECDSA recovery
    //   0x02 SHA256
    //   0x03 RIPEMD160
    //   0x04 IDENTITY
    //
    // Byzantium adds:
    //   0x05 MODEXP        - modular exponentiation
    //   0x06 BN256ADD      - bn256 elliptic curve addition
    //   0x07 BN256MUL      - bn256 scalar multiplication
    //   0x08 BN256PAIRING  - bn256 pairing check
    //
    // Istanbul adds:
    //   0x09 BLAKE2F       - Blake2 compression function
    //
    // Cancun adds:
    //   0x0a KZG_POINT_EVALUATION  (EIP-4844; needs c-kzg or Swift KZG)
    //
    // Prague adds the BLS12-381 suite:
    //   0x0b BLS12_G1ADD
    //   0x0c BLS12_G1MSM
    //   0x0d BLS12_G2ADD
    //   0x0e BLS12_G2MSM
    //   0x0f BLS12_PAIRING
    //   0x10 BLS12_MAP_FP_TO_G1
    //   0x11 BLS12_MAP_FP2_TO_G2

    /// TODO(precompiles): the entire suite is missing. Suggested phasing for a follow-up:
    ///   1. IDENTITY (trivial), SHA256, RIPEMD160 — CryptoSwift covers all three.
    ///   2. MODEXP — pure-Swift bigint loop on top of `BigUInt`.
    ///   3. ECRECOVER — requires secp256k1 (see `Eip7702.SignedAuthorization.recoverAddress`).
    ///   4. BN256_*  — requires a pairing-friendly curve library; significant.
    ///   5. BLAKE2F — pure-Swift implementation of the Blake2 G compression.
    ///   6. KZG_POINT_EVALUATION (Cancun) — requires `c-kzg` C library or a Swift KZG impl.
    ///   7. BLS12-381 (Prague) — requires `blst` C library or Swift BLS impl.
}
