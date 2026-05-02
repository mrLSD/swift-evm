import Foundation
import Interpreter
import PrimitiveTypes

/// Convert decoded JSON `AccountsState` into the runtime account-and-storage maps the test
/// `Backend` expects.
///
/// Mirrors Rust's `StateAccount → MemoryAccount` conversion (`aurora-evm::evm-tests::types::
/// account_state::From<StateAccount>`): zero-value storage entries are filtered out, and
/// missing `code` becomes `[]`.
enum PreStateBuilder {
    typealias Accounts = [H160: (BasicAccount, [UInt8])]
    typealias Storage = [H160: [H256: H256]]

    static func build(_ state: AccountsState) -> (Accounts, Storage) {
        var accounts: Accounts = [:]
        var storage: Storage = [:]
        accounts.reserveCapacity(state.accounts.count)
        storage.reserveCapacity(state.accounts.count)
        for (addr, acc) in state.accounts {
            accounts[addr] = (BasicAccount(balance: acc.balance, nonce: acc.nonce), acc.code ?? [])
            // Filter zero-value entries — mirrors `if v.is_zero() { None }` in Rust.
            let nonZero = acc.storage.filter { !$0.value.isZero }
            if !nonZero.isEmpty {
                storage[addr] = nonZero
            }
        }
        return (accounts, storage)
    }
}
