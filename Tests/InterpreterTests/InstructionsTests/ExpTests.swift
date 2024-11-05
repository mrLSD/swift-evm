@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExpSpec: QuickSpec {
    struct Handler: InterpreterHandler {
        func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine.ExitError? {
            nil
        }
    }

    override class func spec() {
        describe("Instruction Exp") {
            let handler = Handler()

            it("2 exp 6") {
                var m = Machine(data: [], code: [Opcode.EXP.rawValue], gasLimit: 75, handler: handler)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 8)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(15))
            }

            it("2 exp MAX") {
                var m = Machine(data: [], code: [Opcode.EXP.rawValue], gasLimit: 75, handler: handler)

                let _ = m.stack.push(value: U256.MAX)
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(75))
            }

            it("`a exp b`, when `b` not in the stack") {
                var m = Machine(data: [], code: [Opcode.EXP.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }

            it("(a exp 0)") {
                var m = Machine(data: [], code: [Opcode.EXP.rawValue], gasLimit: 10, handler: handler)

                let _ = m.stack.push(value: U256(from: 0))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
            }

            it("Add with OutOfGas result") {
                var m = Machine(data: [], code: [Opcode.EXP.rawValue], gasLimit: 2, handler: handler)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
        }

        it("log2floor [0,0,0,0]") {
            let u256Value = U256(from: [0, 0, 0, 0])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 0

            expect(result).to(equal(expected))
        }

        it("log2floor [2,0,0,0]") {
            let u256Value = U256(from: [2, 0, 0, 0])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 1

            expect(result).to(equal(expected))
        }

        it("log2floor [1,0,0,0]") {
            let u256Value = U256(from: [1, 0, 0, 0])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 0

            expect(result).to(equal(expected))
        }

        it("log2floor [0,1,0,0]") {
            let u256Value = U256(from: [0, 1, 0, 0])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 64

            expect(result).to(equal(expected))
        }

        it("log2floor [0,0,1,0]") {
            let u256Value = U256(from: [0, 0, 1, 0])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 128

            expect(result).to(equal(expected))
        }

        it("log2floor [0,0,0,1]") {
            let u256Value = U256(from: [0, 0, 0, 1])
            let result = GasConstant.log2floor(u256Value)
            let expected: UInt64 = 192

            expect(result).to(equal(expected))
        }
    }
}
