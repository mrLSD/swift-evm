import Foundation
import PrimitiveTypes

/// EIP-4844 constants and helpers used by the test runner for blob gas pricing.
///
/// Mirrors `aurora-evm::evm-tests::types::blob` and `::eip_4844`.
public enum Eip4844 {
    /// Gas consumed by a single data blob (= blob byte size).
    public static let GAS_PER_BLOB: UInt64 = 1 << 17
    public static let MAX_BLOBS_PER_BLOCK_CANCUN: UInt64 = 6
    public static let MAX_BLOBS_PER_BLOCK_ELECTRA: UInt64 = 9
    public static let TARGET_BLOB_GAS_PER_BLOCK: UInt64 = 786_432
    public static let MIN_BLOB_GASPRICE: UInt64 = 1
    public static let BLOB_GASPRICE_UPDATE_FRACTION: UInt64 = 3_338_477
    public static let VERSIONED_HASH_VERSION_KZG: UInt8 = 0x01

    /// EIP-4844 helper. Saturating-subtract of the parent's `(excess + used)` against the target.
    public static func calcExcessBlobGas(parentExcessBlobGas: UInt64, parentBlobGasUsed: UInt64) -> UInt64 {
        let sum = parentExcessBlobGas &+ parentBlobGasUsed
        return sum >= TARGET_BLOB_GAS_PER_BLOCK ? sum - TARGET_BLOB_GAS_PER_BLOCK : 0
    }

    /// EIP-4844 `get_blob_gasprice` via Taylor-series `fake_exponential`.
    public static func calcBlobGasPrice(excessBlobGas: UInt64) -> U128 {
        return fakeExponential(
            factor: MIN_BLOB_GASPRICE,
            numerator: excessBlobGas,
            denominator: BLOB_GASPRICE_UPDATE_FRACTION
        )
    }

    /// EIP-4844 helper used to compute a transaction's blob data fee.
    public static func getTotalBlobGas(blobHashesLen: Int) -> UInt64 {
        return GAS_PER_BLOB &* UInt64(blobHashesLen)
    }

    /// Approximates `factor * e^(numerator / denominator)` via Taylor expansion.
    /// `denominator` must be non-zero. NOT production-safe (no overflow checks);
    /// matches the Rust reference for test parity.
    public static func fakeExponential(factor: UInt64, numerator: UInt64, denominator: UInt64) -> U128 {
        precondition(denominator != 0, "fakeExponential: denominator must not be zero")

        // Use U256 internally to avoid overflow during the Taylor accumulation, then narrow.
        let factorBig = U256(from: factor)
        let numeratorBig = U256(from: numerator)
        let denominatorBig = U256(from: denominator)

        var i: UInt64 = 1
        var output = U256.ZERO
        var numeratorAccum = factorBig * denominatorBig
        while !numeratorAccum.isZero {
            output += numeratorAccum
            let nextNumerator = numeratorAccum * numeratorBig
            let nextDenominator = denominatorBig * U256(from: i)
            numeratorAccum = nextNumerator / nextDenominator
            i &+= 1
        }
        let result = output / denominatorBig
        // Narrow to U128. The Rust reference returns u128, so callers expect ≤ 16-byte width.
        return U128.fromBigEndian(from: Array(result.toBigEndian.suffix(16)))
    }
}

/// Block-level blob gas summary derived from `StateEnv` fields.
///
/// Mirrors `aurora-evm::evm-tests::types::blob::BlobExcessGasAndPrice`.
public struct BlobExcessGasAndPrice: Equatable, Sendable {
    public let excessBlobGas: UInt64
    public let blobGasPrice: U128

    public init(excessBlobGas: UInt64) {
        self.excessBlobGas = excessBlobGas
        self.blobGasPrice = Eip4844.calcBlobGasPrice(excessBlobGas: excessBlobGas)
    }

    public static func fromParent(parentExcessBlobGas: UInt64, parentBlobGasUsed: UInt64) -> Self {
        let excess = Eip4844.calcExcessBlobGas(
            parentExcessBlobGas: parentExcessBlobGas,
            parentBlobGasUsed: parentBlobGasUsed
        )
        return Self(excessBlobGas: excess)
    }

    /// Mirrors Rust `from_env`: prefer `currentExcessBlobGas`; else derive from `parentBlobGasUsed`+`parentExcessBlobGas`.
    public static func fromEnv(_ env: StateEnv) -> Self? {
        if let cur = env.currentExcessBlobGas {
            return Self(excessBlobGas: cur)
        }
        if let used = env.parentBlobGasUsed, let pex = env.parentExcessBlobGas {
            return fromParent(parentExcessBlobGas: pex, parentBlobGasUsed: used)
        }
        return nil
    }
}
