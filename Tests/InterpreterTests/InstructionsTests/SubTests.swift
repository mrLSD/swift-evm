@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSubSpec: QuickSpec {
    struct Handler: InterpreterHandler {
        func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
            nil
        }
    }

    override class func spec() {
        describe("Instruction Sub") {
            let handler = Handler()
            it("Sub 3-2") {
                var m = Machine(data: [], code: [Opcode.SUB.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Sub 5-10 with overflow") {
                var m = Machine(data: [], code: [Opcode.SUB.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 10))
                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [UInt64.max-4, UInt64.max, UInt64.max, UInt64.max])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Sub `a-b`, when `b` not in the stack") {
                var m = Machine(data: [], code: [Opcode.SUB.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Sub max values") {
                var m = Machine(data: [], code: [Opcode.SUB.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: [UInt64.max-9, UInt64.max-6, UInt64.max-4, UInt64.max-2]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-5, UInt64.max-3, UInt64.max-2, UInt64.max-1]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [4, 3, 2, 1])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("Sub with OutOfGas result") {
                var m = Machine(data: [], code: [Opcode.SUB.rawValue], gasLimit: 2, handler: handler)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(2))
            }
        }
    }
}
