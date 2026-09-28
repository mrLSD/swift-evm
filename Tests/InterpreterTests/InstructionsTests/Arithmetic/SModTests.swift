@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSModSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.SMOD, gasLimit: 10)
    }

    override class func spec() {
        describe("Instruction SMod") {
            it("preserves a negative dividend smaller than the divisor") {
                let m = Self.machine
                let minusSix = U256(from: [.max - 5, .max, .max, .max])
                _ = m.stack.push(value: U256(from: 10))
                _ = m.stack.push(value: minusSix)
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.peek(indexFromTop: 0)).to(beSuccess(minusSix))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("preserves remainder signs when word division carries the high remainder bit") {
                for negativeDividend in [false, true] {
                    for negativeDivisor in [false, true] {
                        let m = Self.machine
                        let dividend = negativeDividend
                            ? U256(from: [0, 0x8000000000000000, .max, .max])
                            : U256(from: [0, 0x8000000000000000, 0, 0])
                        let divisor = negativeDivisor
                            ? U256(from: [1, .max, .max, .max])
                            : U256(from: UInt64.max)
                        let expected = negativeDividend
                            ? U256(from: [0x8000000000000000, .max, .max, .max])
                            : U256(from: 0x8000000000000000)

                        _ = m.stack.push(value: divisor)
                        _ = m.stack.push(value: dividend)
                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.peek(indexFromTop: 0)).to(beSuccess(expected), description: "negative dividend \(negativeDividend), negative divisor \(negativeDivisor)")
                        expect(m.stack.length).to(equal(1))
                        expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
                    }
                }
            }

            it("5 % 2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("-5 % 2") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: I256(from: [5, 0, 0, 0], signExtend: true).toU256)
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(I256(from: [1, 0, 0, 0], signExtend: true).toU256))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("-5 % 0") {
                let m = Self.machine

                _ = m.stack.push(value: U256.ZERO)
                _ = m.stack.push(value: I256(from: [5, 0, 0, 0], signExtend: true).toU256)
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
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

                _ = m.stack.push(value: U256(from: [UInt64.max - 1, UInt64.max - 1, UInt64.max - 1, UInt64.max - 1]))
                _ = m.stack.push(value: U256(from: [UInt64.max - 1, 0, 0, 0]))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [18446744073709551614, 0, 0, 0])))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
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
                expect(m.gas.remaining).to(equal(10 - GasConstant.LOW))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.SMOD, gasLimit: 2)

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
