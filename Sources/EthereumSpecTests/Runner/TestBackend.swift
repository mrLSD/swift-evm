import Foundation
import Interpreter
import PrimitiveTypes

/// Read-only `Backend` implementation backed by a `Vicinity` (block env) and an in-memory
/// account/storage map. Used by both `vm` and `state` runners as the authoritative
/// view of "before-execution" world state.
///
/// Mirrors `aurora-evm::backend::MemoryBackend` for the read side. Mutating state
/// modifications would normally happen at the transaction level (`Transactor`),
/// which is currently stubbed — so for the `vm` subcommand the backend is effectively
/// read-only and any state-mutating opcode (SSTORE, etc.) will hit `InvalidOpcode`
/// in the partial Swift `Machine` and be reported as skipped.
final class TestBackend: Backend {
    let vicinity: Vicinity
    /// Address → (BasicAccount, code).
    var accounts: [H160: (BasicAccount, [UInt8])]
    /// Address → storage slots.
    var storage: [H160: [H256: H256]]

    init(
        vicinity: Vicinity,
        accounts: [H160: (BasicAccount, [UInt8])],
        storage: [H160: [H256: H256]]
    ) {
        self.vicinity = vicinity
        self.accounts = accounts
        self.storage = storage
    }

    // MARK: - Block environment

    func gasPrice() -> U256 { vicinity.gasPrice }
    func origin() -> H160 { vicinity.origin }
    func blockHash(number: U256) -> H256 {
        // The corpus rarely populates explicit block hashes; mirror Rust which returns zero
        // when the requested number is out of range.
        guard let idx = number.getInt, idx < vicinity.blockHashes.count else { return H256.ZERO }
        return vicinity.blockHashes[idx]
    }
    func blockNumber() -> U256 { vicinity.blockNumber }
    func blockCoinbase() -> H160 { vicinity.blockCoinbase }
    func blockTimestamp() -> U256 { vicinity.blockTimestamp }
    func blockDifficulty() -> U256 { vicinity.blockDifficulty }
    func blockRandomness() -> H256? { vicinity.blockRandomness }
    func blockGasLimit() -> U256 { vicinity.blockGasLimit }
    func blockBaseFeePerGas() -> U256 { vicinity.blockBaseFeePerGas }
    func chainId() -> U256 { vicinity.chainId }

    // MARK: - Account state

    func exists(address: H160) -> Bool { accounts[address] != nil }

    func basic(address: H160) -> BasicAccount {
        accounts[address]?.0 ?? BasicAccount(balance: U256.ZERO, nonce: U256.ZERO)
    }

    func code(address: H160) -> [UInt8] {
        accounts[address]?.1 ?? []
    }

    func storage(address: H160, index: H256) -> H256 {
        storage[address]?[index] ?? H256.ZERO
    }

    func isEmptyStorage(address: H160) -> Bool {
        (storage[address]?.isEmpty ?? true)
    }

    func originalStorage(address: H160, index: H256) -> H256? {
        // For test runs the original-storage view equals the pre-state view. The state runner
        // (Phase 5+) will need to revisit this when overlaying speculative writes from the
        // transactor — but that work hasn't landed.
        storage[address]?[index]
    }

    // MARK: - EIP-4844

    func blobGasPrice() -> U128 { vicinity.blobGasPrice ?? U128.ZERO }

    func getBlobHash(index: UInt) -> U256? {
        let i = Int(index)
        guard i < vicinity.blobHashes.count else { return nil }
        return vicinity.blobHashes[i]
    }
}
