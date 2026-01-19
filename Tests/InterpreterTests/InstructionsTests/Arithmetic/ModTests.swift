@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionModSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.MOD, gasLimit: 10)
    }

    override class func spec() {
        describe("Instruction Mod") {
            it("5 % 2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 5))
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
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10))
            }

            it("max values 1") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [18446744073709551614, 0, 0, 0])))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10-GasConstant.LOW))
            }

            it("max values 2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10-GasConstant.LOW))
            }

            it("by zero") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10-GasConstant.LOW))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.MOD, gasLimit: 2)

                _ = m.stack.push(value: U256(from: 5))
                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(2))
            }

            it("check stack") {
                let m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))

                let m1 = Self.machine
                _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.stack.length).to(equal(1))
                expect(m1.gas.remaining).to(equal(10))

                let m2 = Self.machine
                _ = m2.stack.push(value: U256(from: 2))
                _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m2.stack.length).to(equal(1))
                expect(m2.gas.remaining).to(equal(10-GasConstant.LOW))
            }
        }
    }
}
