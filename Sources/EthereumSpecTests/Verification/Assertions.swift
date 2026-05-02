import Foundation
import Interpreter

/// Maps spec-test `expectException` strings to internal failure reasons.
///
/// Mirrors the spec-by-spec match cascade in
/// `aurora-evm::evm-tests::assertions.rs::{assert_vicinity_validation, check_validate_exit_reason,
/// assert_call_exit_exception, check_create_exit_reason}`. Rather than reproduce the cascade
/// verbatim (per-spec, per-reason, per-state), we encode it as a flat lookup table:
///
///   - `validationExceptions[reason]` → set of accepted exception strings
///   - `validationExceptionsBySpec[reason][spec]` → narrower override when the spec's
///     accepted strings differ
///
/// Caller checks membership and decides whether to count the test as `failed` or as a matched
/// expected-exception (which counts as a pass under the test corpus's semantics).
///
/// Currently nothing in the Swift port reaches these assertions — the `Transactor` seam
/// throws `notImplemented` first. Phase 7 lands the table so the wiring in `StateRunner`
/// (post-Phase-9 transactor) can call it without further plumbing.
enum Assertions {
    /// Accepted `expectException` strings keyed by `InvalidTxReason` (pre-execution validation).
    /// The set is the *union* across all specs; spec-specific narrowing lives in
    /// `validationExceptionsBySpec` below for the cases where the Rust harness rejects strings
    /// that are accepted on adjacent forks.
    static let validationExceptions: [InvalidTxReason: Set<String>] = [
        .outOfFund: [
            "TR_NoFunds",
            "TR_NoFundsX",
            "TransactionException.INSUFFICIENT_ACCOUNT_FUNDS",
            "TransactionException.INSUFFICIENT_MAX_FEE_PER_BLOB_GAS",
            "TransactionException.INSUFFICIENT_ACCOUNT_FUNDS|TransactionException.GASLIMIT_PRICE_PRODUCT_OVERFLOW"
        ],
        .gasLimitReached: [
            "TR_GasLimitReached",
            "TransactionException.GAS_ALLOWANCE_EXCEEDED"
        ],
        .intrinsicGas: [
            "IntrinsicGas",
            "TR_IntrinsicGas",
            "TR_NoFundsOrGas",
            "TransactionException.INTRINSIC_GAS_TOO_LOW",
            "TransactionException.INSUFFICIENT_ACCOUNT_FUNDS|TransactionException.INTRINSIC_GAS_TOO_LOW",
            "TransactionException.INTRINSIC_GAS_TOO_LOW|TransactionException.INTRINSIC_GAS_BELOW_FLOOR_GAS_COST"
        ],
        .blobVersionNotSupported: [
            "TR_BLOBVERSION_INVALID",
            "TransactionException.TYPE_3_TX_INVALID_BLOB_VERSIONED_HASH"
        ],
        .blobCreateTransaction: [
            "TR_BLOBCREATE",
            "TransactionException.TYPE_3_TX_CONTRACT_CREATION"
        ],
        .blobGasPriceGreaterThanMax: [
            "TransactionException.INSUFFICIENT_MAX_FEE_PER_BLOB_GAS"
        ],
        .tooManyBlobs: [
            "TR_BLOBLIST_OVERSIZE",
            "TransactionException.TYPE_3_TX_BLOB_COUNT_EXCEEDED",
            "TransactionException.TYPE_3_TX_MAX_BLOB_GAS_ALLOWANCE_EXCEEDED|TransactionException.TYPE_3_TX_BLOB_COUNT_EXCEEDED"
        ],
        .emptyBlobs: [
            "TR_EMPTYBLOB",
            "TransactionException.TYPE_3_TX_ZERO_BLOBS"
        ],
        .maxFeePerBlobGasNotSupported: [
            "TransactionException.TYPE_3_TX_PRE_FORK|TransactionException.TYPE_3_TX_ZERO_BLOBS"
        ],
        .blobVersionedHashesNotSupported: [
            "TR_TypeNotSupportedBlob",
            "TransactionException.TYPE_3_TX_PRE_FORK"
        ],
        .invalidAuthorizationChain: [
            "TransactionException.TYPE_4_INVALID_AUTHORIZATION_FORMAT"
        ],
        .invalidAuthorizationSignature: [
            "TransactionException.TYPE_4_INVALID_AUTHORITY_SIGNATURE"
        ],
        .authorizationListNotExist: [
            "TransactionException.TYPE_4_EMPTY_AUTHORIZATION_LIST",
            "TransactionException.TYPE_4_TX_CONTRACT_CREATION"
        ],
        .createTransaction: [
            "TransactionException.TYPE_4_TX_CONTRACT_CREATION"
        ],
        .gasFloorMoreThanGasLimit: [
            "TransactionException.INTRINSIC_GAS_TOO_LOW",
            "TransactionException.INTRINSIC_GAS_BELOW_FLOOR_GAS_COST",
            "TransactionException.INTRINSIC_GAS_TOO_LOW|TransactionException.INTRINSIC_GAS_BELOW_FLOOR_GAS_COST"
        ],
        .authorizationListNotSupportedForCreate: [
            "TransactionException.TYPE_4_TX_CONTRACT_CREATION"
        ],
        .authorizationListNotSupported: [
            "TransactionException.TYPE_4_TX_PRE_FORK"
        ],
        .accessListNotSupported: [
            "TransactionException.TYPE_1_TX_PRE_FORK"
        ],
        .gasPriceEip1559: [
            // Only Istanbul/Berlin reject EIP-1559 fields; cf. assert_vicinity_validation.
            "TR_TypeNotSupported",
            "TR_TypeNotSupportedBlob",
            "TransactionException.TYPE_2_TX_PRE_FORK"
        ],
        .priorityFeeTooLarge: [
            "tipTooHigh",
            "TR_TipGtFeeCap",
            "TransactionException.PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS"
        ],
        .gasPriceLessThanBlockBaseFee: [
            "lowFeeCap",
            "TR_FeeCapLessThanBlocks",
            "TransactionException.INSUFFICIENT_MAX_FEE_PER_GAS"
        ]
    ]

    /// Per-spec narrowing for reasons whose accepted strings differ across forks.
    /// Falls through to `validationExceptions[reason]` if no entry is present.
    static let validationExceptionsBySpec: [InvalidTxReason: [Spec: Set<String>]] = [
        .priorityFeeTooLarge: [
            .Merge: ["TR_TipGtFeeCap"],
            .Shanghai: ["TR_TipGtFeeCap"],
            .Cancun: ["TR_TipGtFeeCap", "TransactionException.PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS"],
            .Prague: ["TransactionException.PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS"]
        ],
        .gasPriceLessThanBlockBaseFee: [
            .London: ["lowFeeCap", "TR_FeeCapLessThanBlocks"],
            .Merge: ["TR_FeeCapLessThanBlocks"],
            .Shanghai: ["TR_FeeCapLessThanBlocks"]
        ],
        .gasPriceEip1559: [
            .Istanbul: ["TR_TypeNotSupported", "TR_TypeNotSupportedBlob", "TransactionException.TYPE_2_TX_PRE_FORK"],
            .Berlin: ["TR_TypeNotSupported", "TR_TypeNotSupportedBlob", "TransactionException.TYPE_2_TX_PRE_FORK"]
        ]
    ]

    /// Accepted strings for `Machine.ExitError` outcomes inside CREATE-style failures.
    /// Mirrors `check_create_exit_reason`. `Machine.ExitError` does not conform to `Hashable`
    /// (one of its associated cases — `MemoryOperation` — wraps a non-Hashable payload),
    /// so we dispatch via a function rather than a dictionary.
    ///
    /// Note: `CreateContractLimit` is not yet present in the Swift `Machine.ExitError` enum.
    /// When it lands, add a case here for it accepting:
    ///   `TR_InitCodeLimitExceeded`, `TransactionException.INITCODE_SIZE_EXCEEDED`.
    static func createExitErrorExceptions(_ error: Machine.ExitError) -> Set<String> {
        switch error {
        case .OutOfGas: return ["TransactionException.INTRINSIC_GAS_TOO_LOW"]
        case .MaxNonce: return ["TR_NonceHasMaxValue", "TransactionException.NONCE_IS_MAX"]
        default: return []
        }
    }

    /// EIP-3607 (empty-EOA-create-caller) accepted strings. Used by `assert_empty_create_caller`.
    static let emptyCreateCallerExceptions: Set<String> = [
        "SenderNotEOA",
        "TransactionException.SENDER_NOT_EOA"
    ]

    /// Returns `true` if `expected` is an accepted match for the given pre-execution validation
    /// `reason` on `spec`. Falls back to the spec-agnostic table when the spec has no override.
    static func matchesValidation(reason: InvalidTxReason, expected: String, spec: Spec) -> Bool {
        if let perSpec = validationExceptionsBySpec[reason]?[spec] {
            return perSpec.contains(expected)
        }
        // Coverage note: every `InvalidTxReason` case has an entry in `validationExceptions`,
        // so the right-hand `?? false` is structurally unreachable. Kept as a defensive default
        // so a future case added to the enum without a table entry doesn't crash.
        return validationExceptions[reason]?.contains(expected) ?? false
    }

    /// Returns `true` if `expected` is an accepted match for the given CREATE-stage exit error.
    static func matchesCreateExit(error: Machine.ExitError, expected: String) -> Bool {
        return createExitErrorExceptions(error).contains(expected)
    }

    /// Returns `true` for the EIP-3607 "sender is not an EOA" exception strings.
    static func matchesEmptyCreateCaller(expected: String) -> Bool {
        return emptyCreateCallerExceptions.contains(expected)
    }
}
