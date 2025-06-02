// NOTE: we're testing each opcode separately. And it includes be default
// each step of Machine eval loop.

@testable import Interpreter
import PrimitiveTypes

struct TestHandler: InterpreterHandler {
    func beforeOpcodeExecution(machine: Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
        nil
    }
}

enum TestMachine {
    /// Init simple Machine
    static func machine(opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, handler: TestHandler())
    }

    /// Init simple Machine with Call Input Data
    static func machine(data: [UInt8], opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: data, code: [opcode.rawValue], gasLimit: gasLimit, handler: TestHandler())
    }

    /// Init Machine with Call Input Data and predefined code with array `Opcode` type and `memoryLimit`
    static func machine(data: [UInt8], opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: data, code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type
    static func machine(opcodes code: [Opcode], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, handler: TestHandler())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`, and hardFork
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int, HardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, handler: TestHandler(), hardFork: HardFork)
    }

    /// Init Machine with predefined code with raw data
    static func machine(rawCode code: [UInt8], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code, gasLimit: gasLimit, handler: TestHandler())
    }
}
