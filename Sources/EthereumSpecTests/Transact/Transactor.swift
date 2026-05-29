import Foundation
import Interpreter
import PrimitiveTypes

/// EIP-7702 authorization tuple at the transactor seam, after signature recovery.
///
/// Mirrors `aurora-evm::executor::stack::Authorization`. Required by the (currently stubbed)
/// transactor entry points so the eventual real implementation has a stable input shape.
struct Authorization: Sendable {
    let authority: H160
    let address: H160
    let nonce: UInt64
    let isValid: Bool
}

/// The single seam between the test harness and a future Swift implementation of
/// `transact_call` / `transact_create`.
///
/// All state tests pass through `Transactor.call` or `Transactor.create`. Today these throw
/// `Transactor.NotImplemented` and `StateRunner` reports the test as **skipped, not failed**.
/// The detailed TODO header below enumerates what needs to be ported to make a real call work.
///
/// Mapped to Rust:
///   `aurora-evm::executor::stack::StackExecutor::transact_call`
///   `aurora-evm::executor::stack::StackExecutor::transact_create`
///
/// Required pieces (none of which currently exist in the Swift Interpreter):
///   - **Intrinsic gas** calculation (data zero/non-zero costs, access-list, EIP-2930
///     `gas_access_list_address`/`gas_access_list_storage_key`, EIP-7702 auth-list cost,
///     EIP-7623 floor-gas; per-fork variants).
///     Rust: `aurora_evm::gasometer::Gasometer::calculate_intrinsic_gas_and_gas_floor`
///   - **Pre-tx validation** (nonce, sender balance ≥ value + max-fee*gas, sender is EOA,
///     EIP-1559 priority fee ≤ gas price, EIP-4844 blob constraints, EIP-7702 auth chain id).
///     Rust: `Transaction::validate` in `evm-tests/types/transaction.rs`.
///   - **Effective gas price** (base fee + capped priority fee for EIP-1559).
///   - **Caller balance withdrawal & miner reward deposit**.
///   - **Access-list seeding** of cold/warm tracker.
///     Rust feeds `Vec<(H160, Vec<H256>)>` into the executor's `Accessed` set on entry.
///   - **EIP-7702 authorization processing** — set delegated code on each authority,
///     bump nonce, charge per-auth gas. Requires secp256k1 ECDSA recovery (still stubbed
///     in `Eip7702.SignedAuthorization.recoverAddress()`).
///   - **Call vs create dispatch** — for create, derive contract address via CREATE/CREATE2
///     rules; pre-fund with `value`; run init code; deploy returned bytes; check max-init-code.
///   - **Sub-call frame management** — current `Machine` is a single-frame interpreter; sub-calls
///     (CALL/CALLCODE/DELEGATECALL/STATICCALL) need their own frames + return-data plumbing.
///   - **Precompile dispatch** — see `Runner/PrecompileRegistry.swift` (Phase 9 stub).
///   - **Refunds** — SSTORE clears, SELFDESTRUCT, EIP-2929 cold/warm; capped at `max_refund_quotient`
///     (1/5 in London+, 1/2 pre-London).
///   - **Final gas accounting** + **state delta materialization** (`Apply::Modify` / `::Delete`).
enum Transactor {
    enum TransactorError: Error, Equatable, Sendable {
        case notImplemented(String)
    }

    /// Bundle of inputs needed by either entry point. Built once per (StateTestCase × Spec × variant)
    /// by `StateRunner` and threaded through whichever dispatch path applies.
    struct Input: Sendable {
        let spec: Spec
        let caller: H160
        let to: H160?
        let value: U256
        let data: [UInt8]
        let gasLimit: UInt64
        let accessList: [(H160, [H256])]
        let authorizationList: [Authorization]
    }

    struct Output: Sendable {
        let exitReason: Machine.ExitReason
        let returnData: [UInt8]
        let gasUsed: UInt64
    }

    static func call(input: Input, backend: TestBackend) throws -> Output {
        throw TransactorError.notImplemented("transact_call: see Transactor.swift TODO header")
    }

    static func create(input: Input, backend: TestBackend) throws -> Output {
        throw TransactorError.notImplemented("transact_create: see Transactor.swift TODO header")
    }
}
