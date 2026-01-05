// NOTE: we're testing each opcode separately. And it includes be default
// each step of Machine eval loop.

@testable import Interpreter
import PrimitiveTypes

class TestHandler: InterpreterHandler {
    static let address1: H160 = .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5001")
    static let address2: H160 = .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5002")

    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
        return nil
    }

    func balance(address: H160) -> U256 {
        switch address {
        case Self.address1:
            return U256(from: 5)
        case Self.address2:
            return U256(from: 10)
        default:
            return U256.ZERO
        }
    }
}

enum TestMachine {
    static func defaultContext() -> Machine.Context {
        Machine.Context(target: H160.ZERO, sender: H160.ZERO, value: U256.ZERO)
    }

    /// Init simple Machine
    static func machine(opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init simple Machine with Call Input Data
    static func machine(data: [UInt8], opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: data, code: [opcode.rawValue], gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init Machine with Call Input Data and predefined code with array `Opcode` type and `memoryLimit`
    static func machine(data: [UInt8], opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: data, code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type
    static func machine(opcodes code: [Opcode], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`, and hardFork
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int, hardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }

    /// Init Machine with predefined code with raw data
    static func machine(rawCode code: [UInt8], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code, gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Create a Machine configured to execute a single opcode under the provided execution context.
    /// - Parameters:
    ///   - opcode: The opcode to include as the Machine's code.
    ///   - gasLimit: The gas limit available to the Machine for execution.
    ///   - context: The execution context (sender, target, value, etc.) to use for the Machine.
    /// - Returns: A Machine set up with the given opcode, gas limit, and context.
    static func machineWithContext(opcode: Opcode, gasLimit: UInt64, context: Machine.Context) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, context: context, state: ExecutionState(), handler: TestHandler())
    }

    /// Create a Machine initialized to execute a single opcode with a fixed 32,000 memory limit.
    /// - Parameters:
    ///   - opcode: The single opcode to place in the Machine's code.
    ///   - gasLimit: The gas limit for the Machine's execution.
    ///   - context: The execution context to use (sender, target, value, etc.).
    ///   - hardFork: The HardFork ruleset to apply to execution.
    /// - Returns: A configured `Machine` containing the provided opcode, gas limit, context, hard fork, and a memory limit of 32,000.
    static func machine(opcode: Opcode, gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }

    /// Creates a Machine initialized with the provided opcodes, gas limit, execution context, and hard-fork rules.
    /// - Parameters:
    ///   - code: The sequence of opcodes to use as the machine's program.
    ///   - gasLimit: The gas limit allotted to the machine.
    ///   - context: The execution context (target, sender, value, etc.).
    ///   - hardFork: The HardFork ruleset to apply to execution.
    /// - Returns: A `Machine` configured with the given parameters, an empty input data buffer, a memory limit of 32000, a fresh `ExecutionState`, and a `TestHandler`.
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }
}