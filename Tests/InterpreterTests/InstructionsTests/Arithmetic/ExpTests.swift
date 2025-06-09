@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExpSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.EXP, gasLimit: 75)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.EXP, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction Exp") {
            it("2 exp 6") {
                let m = Self.machine

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

            it("2 exp 6 for Tangerine hard fork") {
                let m = TestMachine.machine(opcodes: [Opcode.EXP], gasLimit: 75, memoryLimit: 1024, hardFork: .Tangerine)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 8)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(55))
            }

            it("2 exp MAX") {
                let m = Self.machine

                let _ = m.stack.push(value: U256.MAX)
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(75))
            }

            it("`a exp b`, when `b` not in the stack") {
                let m = Self.machine

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(75))
            }

            it("(a exp 0)") {
                let m = Self.machine

                let _ = m.stack.push(value: U256(from: 0))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(65))
            }

            it("Add with OutOfGas result") {
                let m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
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
