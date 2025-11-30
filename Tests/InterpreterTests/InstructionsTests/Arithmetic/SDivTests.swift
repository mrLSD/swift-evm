@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSDivSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.SDIV, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.SDIV, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction SDiv") {
            it("5/2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 2)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("7/-2") {
                let m = Self.machine

                _ = m.stack.push(value: I256(from: [2, 0, 0, 0], signExtend: true).toU256)
                _ = m.stack.push(value: U256(from: 7))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(I256(from: [3, 0, 0, 0], signExtend: true).toU256))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("7/0") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: U256(from: 7))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("`a/b`, when `b` not in the stack") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(5))
            }

            it("max-1 values composition") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("0 / 5") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: U256(from: 5))
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
                let m = Self.machineLowGas

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

                let m1 = Self.machine
                _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m2 = Self.machine
                _ = m2.stack.push(value: U256(from: 2))
                _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
