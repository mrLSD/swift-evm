@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionMulSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.MUL, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.MUL, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction Mul") {
            it("2 * 3") {
                let m = Self.machine

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 6)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("`a * b`, when `b` not in the stack") {
                let m = Self.machine

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(5))
            }

            it("max values") {
                let m = Self.machine

                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [4, 4, 5, 6])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("Mul with OutOfGas result") {
                let m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(2))
            }

            it("check stack") {
                let m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m1 = Self.machine
                let _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m2 = Self.machine
                let _ = m2.stack.push(value: U256(from: 2))
                let _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
