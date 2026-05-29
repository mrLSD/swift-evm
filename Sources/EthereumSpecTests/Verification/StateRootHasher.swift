import CryptoSwift
import Foundation
import Interpreter
import PrimitiveTypes

/// Computes the `state_root` hash of a world state for comparison against `PostState.hash`.
///
/// **Status: stubbed at the trie layer.**
///
/// The Rust reference (`aurora-evm::evm-tests::types::account_state::MemoryAccountsState::
/// check_valid_hash`) computes the root via `ethereum::util::sec_trie_root` — a *secure*
/// Merkle Patricia Trie where keys are keccak'd before insertion and the trie is built per
/// the spec in https://ethereum.org/en/developers/docs/data-structures-and-encoding/patricia-merkle-trie/.
///
/// Implementing a full MPT in Swift is a separately-scopable project (~500 lines, with
/// extension/branch/leaf node logic and RLP-of-children plumbing). It is **not** "RLP +
/// keccak of the sorted concatenation" as I initially noted in the plan — that
/// approximation will not match upstream hashes.
///
/// This file delivers everything *up to* the trie root:
///   - per-account `TrieAccount` materialization (incl. `code_hash = keccak(code)`)
///   - per-storage `(key, RLP(U256(value)))` pair materialization
/// …so once a Swift MPT lands, it can drop straight in here without rebuilding the upstream.
///
/// TODO(MPT): implement `secTrieRoot([(key, value)])` and call it from `compute(...)`.
/// Until then, `compute(...)` throws `Stubbed.notImplemented` and `StateRunner` skips the
/// hash check (which is moot today because the transactor seam never produces state deltas).
enum StateRootHasher {
    enum HasherError: Error, Sendable {
        case notImplemented(String)
    }

    /// Compute the state root over all (address → account-with-storage) pairs.
    /// Throws until the MPT layer is wired up.
    static func compute(accounts: [H160: (BasicAccount, [UInt8])], storage: [H160: [H256: H256]]) throws -> H256 {
        // Materialize the per-account input the trie would need.
        // (Computed eagerly so when the MPT lands, the call site doesn't change.)
        _ = buildTrieAccounts(accounts: accounts, storage: storage)
        throw HasherError.notImplemented(
            "Merkle-Patricia Trie root not implemented. See StateRootHasher.swift TODO header."
        )
    }

    /// Visible for testing. Returns the list of `(address-bytes, RLP(TrieAccount))` pairs that
    /// would feed into the secure-trie root function. Storage roots are computed via the same
    /// stubbed trie-root routine (also currently throws — though not exposed from this helper).
    ///
    /// Iterates `accounts.pairsSortedByBytes()` to (a) sort by big-endian H160 bytes via
    /// `memcmp` and (b) avoid the `accounts[addr]!` re-lookup that a key-only sort would force.
    static func buildTrieAccounts(
        accounts: [H160: (BasicAccount, [UInt8])],
        storage: [H160: [H256: H256]]
    ) -> [(H160, [UInt8])] {
        let sortedEntries = accounts.pairsSortedByBytes()
        var out: [(H160, [UInt8])] = []
        out.reserveCapacity(sortedEntries.count)
        for (addr, account) in sortedEntries {
            let (basic, code) = account

            // Per-storage pair list: (H256 key, RLP(U256(value))).
            // Once MPT lands, feed these into a `secTrieRoot` to obtain the storage root.
            // Today we use the empty-trie sentinel as a placeholder so downstream code can
            // exercise `TrieAccount.rlpEncoded()` end-to-end without erroring out.
            let storageRoot = emptyTrieRoot   // TODO(MPT): replace with actual storage root.
            _ = storage[addr]?.map { key, value in
                (key, RLP.encodeU256(value.asU256))
            }

            let codeHashBytes = SHA3(variant: .keccak256).calculate(for: code)
            let codeHash = H256(from: codeHashBytes)

            let trie = TrieAccount(
                nonce: basic.nonce,
                balance: basic.balance,
                storageRoot: storageRoot,
                codeHash: codeHash,
                codeVersion: U256.ZERO
            )
            out.append((addr, trie.rlpEncoded()))
        }
        return out
    }

    /// `keccak256(rlp(NULL))` — RLP of a null/empty *string* is `0x80`, not the empty list `0xc0`.
    /// The well-known "empty Patricia trie root":
    /// `0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421`.
    /// Used as the storage root for accounts with no non-zero storage.
    static let emptyTrieRoot: H256 = {
        let bytes = SHA3(variant: .keccak256).calculate(for: [0x80])
        return H256(from: bytes)
    }()

}

private extension H256 {
    var asU256: U256 {
        return U256.fromBigEndian(from: self.BYTES)
    }
}
