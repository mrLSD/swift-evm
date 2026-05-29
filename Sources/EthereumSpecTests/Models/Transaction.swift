import Foundation
import PrimitiveTypes

/// EIP-2930 access list entry: `(address, [storageKeys])`.
public struct AccessListTuple: Equatable, Sendable {
    public let address: H160
    public let storageKeys: [H256]
}

extension AccessListTuple: Decodable {
    enum CodingKeys: String, CodingKey {
        case address, storageKeys
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try c.decode(H160.self, forKey: .address)
        self.storageKeys = try c.decode([H256].self, forKey: .storageKeys)
    }
}

public typealias AccessList = [AccessListTuple]

/// Transaction envelope type byte (EIP-2718 family).
public enum TxType: UInt8, Sendable {
    case legacy = 0xff           // sentinel; selected when first byte > 0x7f
    case accessList = 1
    case dynamicFee = 2
    case shardBlob = 3
    case eoaAccountCode = 4

    /// Mirrors Rust `TxType::from_tx_bytes`. Returns `nil` if the type byte is invalid.
    public static func from(txBytes: [UInt8]) -> TxType? {
        guard let first = txBytes.first else { return nil }
        if first > 0x7f { return .legacy }
        switch first {
        case 1: return .accessList
        case 2: return .dynamicFee
        case 3: return .shardBlob
        case 4: return .eoaAccountCode
        default: return nil
        }
    }
}

/// Spec-test transaction. Multiple variants are encoded inline via the `data`/`gasLimit`/`value`
/// arrays + `PostState.indexes`.
///
/// Mirrors `aurora-evm::evm-tests::types::transaction::Transaction`.
public struct Transaction: Equatable, Sendable {
    public let txType: UInt8?
    public let data: [[UInt8]]
    public let gasLimit: [U256]
    public let gasPrice: U256?
    public let nonce: U256
    public let secretKey: H256?
    public let sender: H160?
    public let to: H160?
    public let value: [U256]
    public let maxFeePerGas: U256?
    public let maxPriorityFeePerGas: U256?
    public let initCodes: [UInt8]?
    public let accessLists: [AccessList?]
    public let blobVersionedHashes: [U256]
    public let maxFeePerBlobGas: U256?
    public let authorizationList: AuthorizationList?

    /// Pick the `data` variant referenced by `PostState.indexes.data`.
    public func getData(at indexes: PostStateIndexes) -> [UInt8] {
        return data[indexes.data]
    }

    public func getGasLimit(at indexes: PostStateIndexes) -> U256 {
        return gasLimit[indexes.gas]
    }

    public func getValue(at indexes: PostStateIndexes) -> U256 {
        return value[indexes.value]
    }

    /// Resolve the access list tuples for a given variant. Returns `[]` when none.
    public func getAccessList(at indexes: PostStateIndexes) -> [(H160, [H256])] {
        guard indexes.data < accessLists.count else { return [] }
        guard let list = accessLists[indexes.data] else { return [] }
        return list.map { ($0.address, $0.storageKeys) }
    }
}

extension Transaction: Decodable {
    enum CodingKeys: String, CodingKey {
        case txType = "type"
        case data
        case gasLimit
        case gasPrice
        case nonce
        case secretKey
        case sender
        case to
        case value
        case maxFeePerGas
        case maxPriorityFeePerGas
        case initCodes = "initcodes"
        case accessLists
        case blobVersionedHashes
        case maxFeePerBlobGas
        case authorizationList
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.txType = try c.decodeHexUInt8IfPresent(forKey: .txType)
        self.data = try c.decodeHexBytesArray(forKey: .data)
        self.gasLimit = try c.decodeHexU256Array(forKey: .gasLimit)
        self.gasPrice = try c.decodeIfPresent(U256.self, forKey: .gasPrice)
        self.nonce = try c.decode(U256.self, forKey: .nonce)
        self.secretKey = try c.decodeIfPresent(H256.self, forKey: .secretKey)
        self.sender = try c.decodeIfPresent(H160.self, forKey: .sender)
        self.to = try c.decodeIfPresent(H160.self, forKey: .to)
        self.value = try c.decodeHexU256Array(forKey: .value)
        self.maxFeePerGas = try c.decodeIfPresent(U256.self, forKey: .maxFeePerGas)
        self.maxPriorityFeePerGas = try c.decodeIfPresent(U256.self, forKey: .maxPriorityFeePerGas)
        self.initCodes = try c.decodeHexBytesIfPresent(forKey: .initCodes)
        self.accessLists = (try c.decodeIfPresent([AccessList?].self, forKey: .accessLists)) ?? []
        if c.contains(.blobVersionedHashes) {
            self.blobVersionedHashes = try c.decodeHexU256Array(forKey: .blobVersionedHashes)
        } else {
            self.blobVersionedHashes = []
        }
        self.maxFeePerBlobGas = try c.decodeIfPresent(U256.self, forKey: .maxFeePerBlobGas)
        self.authorizationList = try c.decodeIfPresent(AuthorizationList.self, forKey: .authorizationList)
    }
}
