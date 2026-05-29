import Foundation
import PrimitiveTypes

/// Per-account JSON shape under `pre`, `post.state`, etc.
///
/// Mirrors `aurora-evm::evm-tests::types::account_state::StateAccount`.
public struct StateAccount: Equatable, Sendable {
    public let nonce: U256
    public let balance: U256
    public let code: [UInt8]?
    public let storage: [H256: H256]
}

extension StateAccount: Decodable {
    enum CodingKeys: String, CodingKey {
        case nonce, balance, code, storage
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nonce = try c.decode(U256.self, forKey: .nonce)
        self.balance = try c.decode(U256.self, forKey: .balance)
        self.code = try c.decodeHexBytesIfPresent(forKey: .code)
        if c.contains(.storage) {
            self.storage = try c.decodeStorageMap(forKey: .storage)
        } else {
            self.storage = [:]
        }
    }
}

/// Map from address (`H160`) to per-account state.
///
/// Mirrors `aurora-evm::evm-tests::types::account_state::AccountsState`. Rust uses a
/// `BTreeMap` for ordered iteration; Swift `Dictionary` is unordered, so any code
/// that hashes / RLP-encodes this map MUST sort by address big-endian-bytes first.
public struct AccountsState: Equatable, Sendable {
    public let accounts: [H160: StateAccount]

    public init(_ accounts: [H160: StateAccount]) {
        self.accounts = accounts
    }
}

extension AccountsState: Decodable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: StateAccount].self)
        var out: [H160: StateAccount] = [:]
        out.reserveCapacity(raw.count)
        for (key, value) in raw {
            let addr: H160
            do {
                addr = try HexParser.parseH160(key)
            } catch {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid AccountsState address key '\(key)': \(error)"
                ))
            }
            out[addr] = value
        }
        self.accounts = out
    }
}

/// Compact account record used by Rust's state-root hash routine. See
/// `aurora-evm::evm-tests::types::account_state::TrieAccount`. Phase 6 will provide
/// the RLP encoder + Keccak hash that consumes this.
public struct TrieAccount: Equatable, Sendable {
    public let nonce: U256
    public let balance: U256
    public let storageRoot: H256
    public let codeHash: H256
    public let codeVersion: U256

    public init(nonce: U256, balance: U256, storageRoot: H256, codeHash: H256, codeVersion: U256) {
        self.nonce = nonce
        self.balance = balance
        self.storageRoot = storageRoot
        self.codeHash = codeHash
        self.codeVersion = codeVersion
    }
}
