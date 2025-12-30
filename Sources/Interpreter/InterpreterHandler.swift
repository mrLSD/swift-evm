import PrimitiveTypes

/// Interpreter handler used to pass Handler functions to Interpreter to
/// extend functionality for specific needs
public protocol InterpreterHandler {
    /// Run function before `Opcode` execution during evaluation stage in `Machine`
    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine
        .ExitError?

    /// Get environmental account balance for given address.
    func balance(address: H160) -> U256
    /// Get environmental gas price.
    func gasPrice() -> U256
    /// Get environmental transaction origin (sender) address.
    func origin() -> H160
    /// Get environmental transaction chain ID.
    func chainId() -> U256
    /// Get environmental transaction coinbase address.
    func coinbase() -> H160
}
