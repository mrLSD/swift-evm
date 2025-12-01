@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionAddModSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.ADDMOD, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.ADDMOD, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction AddMod") {
            it("`(2 + 6) % 3`") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 3))
                _ = m.stack.push(value: U256(from: 6))
                _ = m.stack.push(value: U256(from: 2))
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
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }

            it("(a + b) % 0") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 0))
                _ = m.stack.push(value: U256(from: 6))
                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("AddMod with OutOfGas result") {
                let m = Self.machineLowGas

                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("check stack") {
                let m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m1 = Self.machine
                _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m2 = Self.machine
                _ = m2.stack.push(value: U256(from: 5))
                _ = m2.stack.push(value: U256(from: 5))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m3 = Self.machine
                _ = m3.stack.push(value: U256(from: 2))
                _ = m3.stack.push(value: U256(from: 2))
                _ = m3.stack.push(value: U256(from: 2))
                m3.evalLoop()
                expect(m3.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
