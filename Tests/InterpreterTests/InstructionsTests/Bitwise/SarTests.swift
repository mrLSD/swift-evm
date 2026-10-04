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
            it("activates at Constantinople across all supported forks") {
                for fork in HardFork.allCases {
                    let m = TestMachine.machine(opcodes: [.SAR], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    m.stackPush(value: U256.MAX)
                    m.stackPush(value: U256(from: 1))

                    m.evalLoop()

                    if fork.rawValue < HardFork.Constantinople.rawValue {
                        expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: "fork=\(fork)")
                        expect(m.gas.remaining).to(equal(10))
                        expect(m.stack.length).to(equal(2))
                    } else {
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "fork=\(fork)")
                        expect(m.gas.remaining).to(equal(7))
                        expect(m.stack.length).to(equal(1))
                        expect(m.stackPop()).to(equal(U256.MAX))
                    }
                }
            }

            it("checks activation before stack and gas requirements") {
                let m = TestMachine.machine(opcodes: [.SAR], gasLimit: 0, memoryLimit: 32, hardFork: .Byzantium)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.length).to(equal(0))
            }

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

            it("matches signed and shift boundaries") {
                func expectSar(_ name: String, _ value: U256, _ shift: U256, _ expected: U256) {
                    let m = Self.machine
                    _ = m.stack.push(value: value)
                    _ = m.stack.push(value: shift)
                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: name)
                    expect(m.stack.peek(indexFromTop: 0)).to(beSuccess(expected), description: name)
                    expect(m.stack.length).to(equal(1), description: name)
                    expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW), description: name)
                }

                expectSar("positive shift zero", U256(from: 7), .ZERO, U256(from: 7))
                expectSar("negative rounding", U256.MAX - U256(from: 2), U256(from: 1), U256.MAX - U256(from: 1))
                expectSar(
                    "minimum shift one",
                    I256.minValue.toU256,
                    U256(from: 1),
                    U256(l0: 0, l1: 0, h0: 0, h1: 0xC000_0000_0000_0000)
                )
                expectSar("positive maximal shift", I256.SIGN_BIT_MASK, .MAX, .ZERO)
                expectSar("negative maximal shift", I256.minValue.toU256, .MAX, .MAX)
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
