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
    /// Get EXTCODEHASH: zero for EIP-161 empty accounts, otherwise the own code hash, without following delegation.
    func codeHash(address: H160) -> H256
    /// Get environmental gas price.
    func gasPrice() -> U256
    /// Get environmental transaction origin (sender) address.
    func origin() -> H160
    /// Get environmental transaction chain ID.
    func chainId() -> U256
    /// Get environmental transaction coinbase address.
    func coinbase() -> H160
    /// Whether the current call forbids state changes.
    func isStatic() -> Bool
    /// Append to the current substate's logs; leave them unchanged on failure.
    func log(address: H160, topics: [H256], data: [UInt8]) -> Result<Void, Machine.ExitError>
}
