// NOTE: we're testing each opcode separately. And it includes be default
// each step of Machine eval loop.

@testable import Interpreter
import PrimitiveTypes

struct TestHandler: InterpreterHandler {
    func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
        nil
    }
}

enum TestMachine {
    /// Init simple Machine
    static func machine(opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, handler: TestHandler())
    }

    /// Init Machine with predefined code with array `Opcode` type
    static func machine(opcodes code: [Opcode], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, handler: TestHandler())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: UInt) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`, and hardFork
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: UInt, HardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, handler: TestHandler(), hardFork: HardFork)
    }

    /// Init Machine with predefined code with raw data
    static func machine(rawCode code: [UInt8], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code, gasLimit: gasLimit, handler: TestHandler())
    }
}
