import PrimitiveTypes

/// Interpreter handler used to pass Handler functions to Interpreter to
/// extend functionality for specific needs
public protocol InterpreterHandler {
    /// Run function before `Opcode` execution ay evaluation stage in Machine
    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine
        .ExitError?

    func balance(address: H160) -> U256
}
