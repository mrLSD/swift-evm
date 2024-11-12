@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionAddModSpec: QuickSpec {
    struct Handler: InterpreterHandler {
        func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
            nil
        }
    }

    override class func spec() {
        describe("Instruction AddMod") {
            let handler = Handler()

            it("`(2 + 6) % 3`") {
                var m = Machine(data: [], code: [Opcode.ADDMOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 6))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 2)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("`(a + b) % c`, when `c` not in the stack") {
                var m = Machine(data: [], code: [Opcode.ADDMOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }

            it("(a + b) % 0") {
                var m = Machine(data: [], code: [Opcode.ADDMOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 0))
                let _ = m.stack.push(value: U256(from: 6))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("Add with OutOfGas result") {
                var m = Machine(data: [], code: [Opcode.ADDMOD.rawValue], gasLimit: 2, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
        }
    }
}
