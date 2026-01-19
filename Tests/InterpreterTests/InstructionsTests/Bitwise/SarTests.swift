@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSarSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.SAR, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.SAR, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction SAR") {
            it("a >>> b") {
                let m = Self.machine

                let expectedValue: UInt64 = 32 >> 3 // 4
                _ = m.stack.push(value: U256(from: 32))
                _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: expectedValue)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("0 >>> b") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 0))
                _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("a >>> 256") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 10))
                _ = m.stack.push(value: U256(from: 256))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("-a >>> 256") {
                let m = Self.machine

                _ = m.stack.push(value: I256(from: [3, 0, 0, 0], signExtend: true).toU256)
                _ = m.stack.push(value: U256(from: 256))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(I256(from: [1, 0, 0, 0], signExtend: true).toU256))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("a >>> 255 (positive boundary)") {
                let m = Self.machine
                _ = m.stack.push(value: U256(from: 10))
                _ = m.stack.push(value: U256(from: 255))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("-a >>> 255 (negative boundary)") {
                let m = Self.machine
                let negativeOne = I256(from: [1, 0, 0, 0], signExtend: true).toU256

                _ = m.stack.push(value: negativeOne)
                _ = m.stack.push(value: U256(from: 255))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(negativeOne))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("-a >>> 3") {
                let m = Self.machine

                let expectedValue: U256 = (I256(from: [32, 0, 0, 0], signExtend: true) >> 3).toU256
                expect(expectedValue).to(equal(I256(from: [4, 0, 0, 0], signExtend: true).toU256))

                _ = m.stack.push(value: I256(from: [32, 0, 0, 0], signExtend: true).toU256)
                _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(expectedValue))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("`a >>> b`, when `b` not in the stack") {
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
