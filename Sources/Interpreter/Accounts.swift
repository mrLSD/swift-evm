import EVMCrypto
import PrimitiveTypes

/// Basic account information.
public struct BasicAccount: Equatable, Sendable {
    /// Account balance.
    public var balance: U256
    /// Account nonce.
    public var nonce: UInt64

    /// Initializes a new `BasicAccount` with the provided balance and nonce.
    public init(balance: U256, nonce: UInt64) {
        self.balance = balance
        self.nonce = nonce
    }

    /// Increment account nonce by 1.
    ///
    /// - Precondition: caller must ensure `nonce < UInt64.max` (see `MemoryState.incNonce`,
    ///   which checks for `UInt64.max` and returns `.MaxNonce` before invoking this method).
    /// - Trap: if `nonce == UInt64.max` at the point of call, the `+= 1` overflow traps
    ///   loudly (Swift's checked arithmetic).
    public mutating func incNonce() {
        nonce += 1
    }

    /// Sets the account's balance to the specified value.
    public mutating func setBalance(_ balance: U256) {
        self.balance = balance
    }

    /// Adds the specified balance to the account's current balance, handling overflow by capping at `U256.MAX`.
    public mutating func addBalance(_ balance: U256) {
        let (newBalance, overflow) = self.balance.overflowAdd(balance)
        self.balance = overflow ? U256.MAX : newBalance
    }

    /// Subtracts the specified balance from the account's current balance, handling underflow by capping at `U256.ZERO`.
    public mutating func subBalance(_ balance: U256) {
        let (newBalance, overflow) = self.balance.overflowSub(balance)
        self.balance = overflow ? U256.ZERO : newBalance
    }
}

extension BasicAccount {
    /// A default `BasicAccount` instance with a balance of zero and a nonce of zero.
    static let `default` = BasicAccount(balance: U256.ZERO, nonce: 0)
}

/// Account state information.
public struct StateAccount: Equatable, Sendable {
    /// Basic account information.
    public var basic: BasicAccount
    /// Account code.
    public var code: [UInt8]?
    /// Hash of `code` (`nil` without code), stored with it so that reads and copies never hash the code again.
    public var codeHash: H256?
    /// Account reset flag.
    public var reset: Bool

    /// Initializes a new `StateAccount` with the provided basic account information, code, and reset flag.
    /// Non-nil code is hashed as by `setCode(_:)`.
    public init(basic: BasicAccount, code: [UInt8]?, reset: Bool) {
        self.basic = basic
        self.reset = reset
        if let code {
            setCode(code)
        }
    }

    /// Sets the code and its hash, which is computed only here; empty code needs no hashing.
    public mutating func setCode(_ code: [UInt8]) {
        self.code = code
        codeHash = code.isEmpty ? .KECCAK_EMPTY : code.withUnsafeBytes { Keccak256.hash($0) }
    }
}
