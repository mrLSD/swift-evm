@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionAndSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.AND, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.AND, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction AND") {
            it("a & b") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 6))
                _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 2)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("`a & b`, when `b` not in the stack") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10))
            }

            it("with OutOfGas result") {
                let m = Self.machineLowGas

                _ = m.stack.push(value: U256(from: 1))
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
                expect(m2.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }
        }
    }
}
