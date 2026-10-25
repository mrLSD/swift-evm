import PrimitiveTypes

/// Interpreter handler used to pass Handler functions to Interpreter to
/// extend functionality for specific needs
public protocol InterpreterHandler {
    /// Run function before `Opcode` execution during evaluation stage in `Machine`
    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine
        .ExitError?

    /// Get environmental account balance for given address.
    func balance(address: H160) -> U256
    /// Get the account's own code, including an EIP-7702 delegation indicator; empty for absent accounts.
    func code(address: H160) -> [UInt8]
    /// Get EXTCODEHASH (EIP-1052): the own code hash, or zero for an absent or EIP-161 empty account, without
    /// following delegation. Over `MemoryState`, read `codeHash(address:)` first and consult `basic(address:)`
    /// only when it is `KECCAK_EMPTY`, so a contract costs one backend read.
    func codeHash(address: H160) -> H256
    /// Read the current transaction's transient storage; an unset slot returns zero, including in static calls.
    func tload(address: H160, index: H256) -> Result<U256, Machine.ExitError>
    /// Write the current transaction's transient storage; leave it unchanged on failure.
    func tstore(address: H160, index: H256, value: U256) -> Result<Void, Machine.ExitError>
    /// Get environmental gas price.
    func gasPrice() -> U256
    /// Get environmental transaction origin (sender) address.
    func origin() -> H160
    /// Get environmental transaction chain ID.
    func chainId() -> U256
    /// Get environmental transaction coinbase address.
    func coinbase() -> H160
    /// Get the current block's Unix timestamp in seconds.
    func blockTimestamp() -> U256
    /// Get the current block's number.
    func blockNumber() -> U256
    /// Get the gas limit of the current block.
    func blockGasLimit() -> U256
    /// Whether the current call forbids state changes.
    func isStatic() -> Bool
    /// Append to the current substate's logs; leave them unchanged on failure.
    func log(address: H160, topics: [H256], data: [UInt8]) -> Result<Void, Machine.ExitError>
}
