import Foundation
import PrimitiveTypes

/// Block environment fields read from the JSON `env` object.
///
/// Mirrors `aurora-evm::evm-tests::types::StateEnv`.
public struct StateEnv: Equatable, Sendable {
    public let blockDifficulty: U256
    public let blockCoinbase: H160
    public let blockGasLimit: U256
    public let blockNumber: U256
    public let blockTimestamp: U256
    public let blockBaseFeePerGas: U256
    public let random: H256?
    public let parentBlobGasUsed: UInt64?
    public let parentExcessBlobGas: UInt64?
    public let currentExcessBlobGas: UInt64?
}

extension StateEnv: Decodable {
    enum CodingKeys: String, CodingKey {
        case blockDifficulty = "currentDifficulty"
        case blockCoinbase = "currentCoinbase"
        case blockGasLimit = "currentGasLimit"
        case blockNumber = "currentNumber"
        case blockTimestamp = "currentTimestamp"
        case blockBaseFeePerGas = "currentBaseFee"
        case random = "currentRandom"
        case parentBlobGasUsed
        case parentExcessBlobGas
        case currentExcessBlobGas
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.blockDifficulty = try c.decode(U256.self, forKey: .blockDifficulty)
        self.blockCoinbase = try c.decode(H160.self, forKey: .blockCoinbase)
        self.blockGasLimit = try c.decode(U256.self, forKey: .blockGasLimit)
        self.blockNumber = try c.decode(U256.self, forKey: .blockNumber)
        self.blockTimestamp = try c.decode(U256.self, forKey: .blockTimestamp)
        if c.contains(.blockBaseFeePerGas) {
            self.blockBaseFeePerGas = try c.decode(U256.self, forKey: .blockBaseFeePerGas)
        } else {
            self.blockBaseFeePerGas = U256.ZERO
        }
        self.random = try c.decodeIfPresent(H256.self, forKey: .random)
        self.parentBlobGasUsed = try c.decodeHexUInt64IfPresent(forKey: .parentBlobGasUsed)
        self.parentExcessBlobGas = try c.decodeHexUInt64IfPresent(forKey: .parentExcessBlobGas)
        self.currentExcessBlobGas = try c.decodeHexUInt64IfPresent(forKey: .currentExcessBlobGas)
    }
}

/// `pre` field of a state test — initial accounts.
public struct PreState: Equatable, Sendable, Decodable {
    public let accounts: AccountsState

    public init(accounts: AccountsState) {
        self.accounts = accounts
    }

    public init(from decoder: Decoder) throws {
        self.accounts = try AccountsState(from: decoder)
    }
}

/// Selectors that pick a single (data, gas, value) variant out of the multi-variant `Transaction`.
public struct PostStateIndexes: Equatable, Sendable, Decodable {
    public let data: Int
    public let gas: Int
    public let value: Int
}

/// Per-(spec, variant) expectation block.
///
/// Mirrors `aurora-evm::evm-tests::types::PostState`.
public struct PostState: Equatable, Sendable {
    public let hash: H256
    public let logs: H256
    public let indexes: PostStateIndexes
    public let expectException: String?
    public let txBytes: [UInt8]
    /// Some test sets emit `state` (legacy) or `postState` (newer). Both are optional.
    public let state: AccountsState?
    public let postState: AccountsState?
}

extension PostState: Decodable {
    enum CodingKeys: String, CodingKey {
        case hash, logs, indexes, expectException, txbytes, state, postState
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hash = try c.decode(H256.self, forKey: .hash)
        self.logs = try c.decode(H256.self, forKey: .logs)
        self.indexes = try c.decode(PostStateIndexes.self, forKey: .indexes)
        self.expectException = try c.decodeIfPresent(String.self, forKey: .expectException)
        self.txBytes = try c.decodeHexBytes(forKey: .txbytes)
        self.state = try c.decodeIfPresent(AccountsState.self, forKey: .state)
        self.postState = try c.decodeIfPresent(AccountsState.self, forKey: .postState)
    }
}

/// Reasons a state-test transaction might be rejected during pre-execution validation.
///
/// Mirrors `aurora-evm::evm-tests::types::InvalidTxReason` 1:1 so the assertion mapping
/// for `expect_exception` strings (Phase 7) can stay symmetric with the Rust runner.
public enum InvalidTxReason: Equatable, Sendable {
    case intrinsicGas
    case outOfFund
    case gasLimitReached
    case priorityFeeTooLarge
    case gasPriceLessThanBlockBaseFee
    case blobCreateTransaction
    case blobVersionNotSupported
    case tooManyBlobs
    case emptyBlobs
    case blobGasPriceGreaterThanMax
    case blobVersionedHashesNotSupported
    case maxFeePerBlobGasNotSupported
    case gasPriceEip1559
    case authorizationListNotExist
    case authorizationListNotSupported
    case authorizationListNotSupportedForCreate
    case invalidAuthorizationChain
    case invalidAuthorizationSignature
    case createTransaction
    case gasFloorMoreThanGasLimit
    case accessListNotSupported
}

/// Top-level shape of a single state-test JSON entry.
///
/// Mirrors `aurora-evm::evm-tests::types::StateTestCase`.
public struct StateTestCase: Equatable, Sendable {
    public let env: StateEnv
    public let preState: PreState
    /// `BTreeMap<Spec, Vec<PostState>>` in Rust. Swift `[Spec: [PostState]]` is unordered;
    /// runner code that needs ordered iteration must sort by `Spec.rawValue`.
    public let postStates: [Spec: [PostState]]
    public let transaction: Transaction
    public let out: [UInt8]?
    public let info: Info?
}

extension StateTestCase: Decodable {
    enum CodingKeys: String, CodingKey {
        case env
        case preState = "pre"
        case postStates = "post"
        case transaction
        case out
        case info = "_info"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.env = try c.decode(StateEnv.self, forKey: .env)
        self.preState = try c.decode(PreState.self, forKey: .preState)

        // `post` is keyed by Spec name (string). Decode as [String: [PostState]] then map.
        let rawPosts = try c.decode([String: [PostState]].self, forKey: .postStates)
        var posts: [Spec: [PostState]] = [:]
        for (specStr, list) in rawPosts {
            guard let spec = Spec(rawString: specStr) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: c.codingPath + [CodingKeys.postStates],
                    debugDescription: "Unknown Spec key in postStates: '\(specStr)'"
                ))
            }
            posts[spec] = list
        }
        self.postStates = posts

        self.transaction = try c.decode(Transaction.self, forKey: .transaction)
        self.out = try c.decodeHexBytesIfPresent(forKey: .out)
        self.info = try c.decodeIfPresent(Info.self, forKey: .info)
    }
}
