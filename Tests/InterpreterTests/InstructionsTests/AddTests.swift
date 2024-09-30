@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionAddSpec: QuickSpec {
    struct Handler: InterpreterHandler {
        func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
            nil
        }
    }

    override class func spec() {
        describe("Instruction Add") {
            let handler = Handler()
            it("Not existed opcode") {
                var m = Machine(data: [], code: [0xEF], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidOpcode(0xEF)))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(10))
            }

            it("Add 1+2") {
                var m = Machine(data: [], code: [Opcode.ADD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 3)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Add `a+b`, when `b` not in the stack") {
                var m = Machine(data: [], code: [Opcode.ADD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Add max values") {
                var m = Machine(data: [], code: [Opcode.ADD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [UInt64.max-3, UInt64.max-2, UInt64.max-2, UInt64.max-2])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Add with OutOfGas result") {
                var m = Machine(data: [], code: [Opcode.ADD.rawValue], gasLimit: 2, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(2))
            }
        }
    }
}
