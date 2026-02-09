import PrimitiveTypes

/// Basic account information.
public struct BasicAccount: Equatable {
    /// Account balance.
    public var balance: U256
    /// Account nonce.
    public var nonce: U256

    /// Initializes a new `BasicAccount` with the provided balance and nonce.
    public init(balance: U256, nonce: U256) {
        self.balance = balance
        self.nonce = nonce
    }

    /// Increment account nonce by 1.
    public mutating func incNonce() {
        self.nonce += U256(from: 1)
    }

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

/// Account state information.
public class StateAccount: Equatable {
    /// Basic account information.
    public var basic: BasicAccount
    /// Account code.
    public var code: [UInt8]?
    /// Account reset flag.
    public var reset: Bool

    /// Initializes a new `StateAccount` with the provided basic account information, code, and reset flag.
    public init(basic: BasicAccount, code: [UInt8]?, reset: Bool) {
        self.basic = basic
        self.code = code
        self.reset = reset
    }
}

public extension StateAccount {
    /// Equatable conformance for `StateAccount`.
    static func == (lhs: StateAccount, rhs: StateAccount) -> Bool {
        return lhs.basic == rhs.basic && lhs.code == rhs.code && lhs.reset == rhs.reset
    }
}
