import Foundation
import PrimitiveTypes

/// JSON `callcreates` entry: a sub-call captured during VM execution.
public struct Call: Equatable, Sendable {
    public let data: [UInt8]
    public let destination: H160?
    public let gasLimit: U256
    public let value: U256
}

extension Call: Decodable {
    enum CodingKeys: String, CodingKey {
        case data, destination, gasLimit, value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try c.decodeHexBytes(forKey: .data)
        self.destination = try c.decodeIfPresent(H160.self, forKey: .destination)
        self.gasLimit = try c.decode(U256.self, forKey: .gasLimit)
        self.value = try c.decode(U256.self, forKey: .value)
    }
}

/// VM test execution parameters (the `exec` block).
public struct ExecutionTransaction: Equatable, Sendable {
    public let address: H160
    public let sender: H160        // JSON: `caller`
    public let code: [UInt8]
    public let data: [UInt8]
    public let gas: U256
    public let gasPrice: U256
    public let origin: H160
    public let value: U256
    public let codeVersion: U256
}

extension ExecutionTransaction: Decodable {
    enum CodingKeys: String, CodingKey {
        case address
        case sender = "caller"
        case code, data, gas, gasPrice, origin, value, codeVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try c.decode(H160.self, forKey: .address)
        self.sender = try c.decode(H160.self, forKey: .sender)
        self.code = try c.decodeHexBytes(forKey: .code)
        self.data = try c.decodeHexBytes(forKey: .data)
        self.gas = try c.decode(U256.self, forKey: .gas)
        self.gasPrice = try c.decode(U256.self, forKey: .gasPrice)
        self.origin = try c.decode(H160.self, forKey: .origin)
        self.value = try c.decode(U256.self, forKey: .value)
        if c.contains(.codeVersion) {
            self.codeVersion = try c.decode(U256.self, forKey: .codeVersion)
        } else {
            self.codeVersion = U256.ZERO
        }
    }
}

/// Top-level shape of a single VM test JSON entry.
///
/// Mirrors `aurora-evm::evm-tests::types::vm::VmTestCase`.
public struct VmTestCase: Equatable, Sendable {
    public let calls: [Call]?
    public let env: StateEnv
    public let transaction: ExecutionTransaction
    /// JSON field `gas` — gas left after execution (when present).
    public let gasLeft: U256?
    public let logs: H256?
    public let output: [UInt8]?
    public let postState: AccountsState?
    public let preState: AccountsState
}

extension VmTestCase: Decodable {
    enum CodingKeys: String, CodingKey {
        case calls = "callcreates"
        case env
        case transaction = "exec"
        case gasLeft = "gas"
        case logs, output = "out"
        case postState = "post"
        case preState = "pre"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.calls = try c.decodeIfPresent([Call].self, forKey: .calls)
        self.env = try c.decode(StateEnv.self, forKey: .env)
        self.transaction = try c.decode(ExecutionTransaction.self, forKey: .transaction)
        self.gasLeft = try c.decodeIfPresent(U256.self, forKey: .gasLeft)
        self.logs = try c.decodeIfPresent(H256.self, forKey: .logs)
        self.output = try c.decodeHexBytesIfPresent(forKey: .output)
        self.postState = try c.decodeIfPresent(AccountsState.self, forKey: .postState)
        self.preState = try c.decode(AccountsState.self, forKey: .preState)
    }
}
