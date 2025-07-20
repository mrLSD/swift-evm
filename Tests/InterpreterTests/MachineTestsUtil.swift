// NOTE: we're testing each opcode separately. And it includes be default
// each step of Machine eval loop.

@testable import Interpreter
import PrimitiveTypes

class TestHandler: InterpreterHandler {
    static let address1: H160 = .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5001")
    static let address2: H160 = .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5002")
    static let testGasPrice: U256 = U256(from: 123)

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

    func gasPrice() -> U256 {
        Self.testGasPrice
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

    static func machineWithContext(opcode: Opcode, gasLimit: UInt64, context: Machine.Context) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, context: context, state: ExecutionState(), handler: TestHandler())
    }

    static func machine(opcode: Opcode, gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }

    static func machine(opcodes code: [Opcode], gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }
}
