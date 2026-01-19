@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSDivSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.SDIV, gasLimit: 10)
    }

    override class func spec() {
        describe("Instruction SDiv") {
            it("5/2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 2)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("7/-2") {
                let m = Self.machine

                _ = m.stack.push(value: I256(from: [2, 0, 0, 0], signExtend: true).toU256)
                _ = m.stack.push(value: U256(from: 7))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(I256(from: [3, 0, 0, 0], signExtend: true).toU256))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("7 / 0") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: U256(from: 7))

                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("-7 / 0") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: I256(from: [7, 0, 0, 0], signExtend: true).toU256)
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("`a/b`, when `b` not in the stack") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10))
            }

            it("max-1 values composition") {
                let m = Self.machine

                // 1. Divisor (Denominator): Pushed first (Bottom of stack).
                // Value: [max-1, max-1, max-1, max-1].
                // In SDIV (Two's Complement), this is a NEGATIVE number with a HUGE magnitude (~2^192).
                // NOTE: This is NOT -2. (-2 would be [max-1, max, max, max]).
                _ = m.stack.push(value: U256(from: [UInt64.max - 1, UInt64.max - 1, UInt64.max - 1, UInt64.max - 1]))

                // 2. Dividend (Numerator): Pushed second (Top of stack).
                // Value: [max-1, 0, 0, 0].
                // This is a POSITIVE number with magnitude ~2^64.
                _ = m.stack.push(value: U256(from: [UInt64.max - 1, 0, 0, 0]))

                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    // Since |Dividend| (~2^64) < |Divisor| (~2^192), the result is 0.
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("divides large positive by -2 (SDIV)") {
                let m = Self.machine

                // op2 = -2 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE
                _ = m.stack.push(value: U256(from: [UInt64.max - 1, UInt64.max, UInt64.max, UInt64.max]))

                // op1 = 2^64 - 2
                _ = m.stack.push(value: U256(from: [UInt64.max - 1, 0, 0, 0]))

                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                let expectedLow: UInt64 = 0x8000000000000001
                let expectedHigh = UInt64.max
                let expectedValue = U256(from: [expectedLow, expectedHigh, expectedHigh, expectedHigh])

                expect(result).to(beSuccess { value in
                    expect(value).to(equal(expectedValue))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("returns zero when dividend is smaller than divisor (SDIV)") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 20))
                _ = m.stack.push(value: U256(from: 10))

                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("0 / 5") {
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
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.SDIV, gasLimit: 2)

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
                expect(m2.gas.remaining).to(equal(10 - GasConstant.LOW))
            }
        }
    }
}
