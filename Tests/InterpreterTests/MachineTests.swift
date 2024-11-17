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
    static func machine(opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, handler: TestHandler())
    }
}
