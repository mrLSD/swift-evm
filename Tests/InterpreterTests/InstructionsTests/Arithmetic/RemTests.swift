@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionRemSpec: QuickSpec {
    struct Handler: InterpreterHandler {
        func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
            nil
        }
    }

    override class func spec() {
        describe("Instruction Mod") {
            let handler = Handler()
            it("5 % 2") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("`a % b`, when `b` not in the stack") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }

            it("max values 1") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [18446744073709551614, 0, 0, 0])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("max values 2") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("by zero") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256.ZERO)
                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("with OutOfGas result") {
                var m = Machine(data: [], code: [Opcode.MOD.rawValue], gasLimit: 2, handler: handler)

                let _ = m.stack.push(value: U256(from: 5))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
        }
    }
}
