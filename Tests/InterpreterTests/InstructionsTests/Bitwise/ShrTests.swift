@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionShrSpec: QuickSpec {
    static var machine: Machine {
        return TestMachine.machine(opcode: Opcode.SHR, gasLimit: 10)
    }

    static var machineLowGas: Machine {
        return TestMachine.machine(opcode: Opcode.SHR, gasLimit: 2)
    }

    override class func spec() {
        describe("Instruction SHR") {
            it("activates at Constantinople across all supported forks") {
                for fork in HardFork.allCases {
                    let m = TestMachine.machine(opcodes: [.SHR], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    m.stackPush(value: U256(from: 6))
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
                        expect(m.stackPop()).to(equal(U256(from: 3)))
                    }
                }
            }

            it("checks activation before stack and gas requirements") {
                let m = TestMachine.machine(opcodes: [.SHR], gasLimit: 0, memoryLimit: 32, hardFork: .Byzantium)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.length).to(equal(0))
            }

            it("a >> b") {
                let m = Self.machine

                let expectedValue: UInt64 = 32 >> 3
                expect(expectedValue).to(equal(4))

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

            it("0 >> b") {
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

            it("a >> 256") {
                let m = Self.machine

                _ = m.stack.push(value: U256.MAX)
                _ = m.stack.push(value: U256(from: 256))
                m.evalLoop()
                let result = m.stack.peek(indexFromTop: 0)

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
            }

            it("`a >> b`, when `b` not in the stack") {
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
