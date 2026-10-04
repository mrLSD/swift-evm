@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionRevertSpec: QuickSpec {
    override class func spec() {
        describe("Instruction REVERT") {
            it("ignores every offset for an empty output without changing memory or gas") {
                let offsets: [U256] = [
                    .ZERO, U256(from: 1), U256(from: UInt64(Int.max)),
                    U256(from: UInt64(Int.max) + 1), U256(from: [0, 1, 0, 0]),
                    U256(from: [0, 0, 1, 0]), U256(from: [0, 0, 0, 1]),
                    U256(from: [0, 0, 0, 1 << 63]), .MAX,
                ]
                for offset in offsets {
                    for initialized in [false, true] {
                        let m = TestMachine.machine(opcode: .REVERT, gasLimit: 0)
                        if initialized {
                            expect(m.memory.set(offset: 0, value: [0xAB], size: 1)).to(beSuccess())
                        }
                        let memoryLength = m.memory.effectiveLength
                        m.stackPush(value: U256(from: 42))
                        m.stackPush(value: .ZERO)
                        m.stackPush(value: offset)
                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Revert)), description: "offset=\(offset)")
                        expect(m.returnRange).to(equal(0 ..< 0))
                        expect(m.memory.get(offset: m.returnRange.lowerBound, size: m.returnRange.count)).to(equal([]))
                        expect(m.memory.effectiveLength).to(equal(memoryLength))
                        expect(m.memory.get(offset: 0, size: 1)).to(equal([initialized ? 0xAB : 0]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.gas.memoryGas.numWords).to(equal(0))
                        expect(m.stack.length).to(equal(1))
                        expect(m.stackPop()).to(equal(U256(from: 42)))
                    }
                }
            }

            it("returns empty output from PUSH32 bytecode with the highest offset bit set") {
                let code: [UInt8] = [Opcode.PUSH1.rawValue, 0, Opcode.PUSH32.rawValue, 0x80]
                    + [UInt8](repeating: 0, count: 31) + [Opcode.REVERT.rawValue]
                let m = TestMachine.machine(rawCode: code, gasLimit: 6)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Revert)))
                expect(m.returnRange).to(equal(0 ..< 0))
                expect(m.gas.remaining).to(equal(0))
                expect(m.memory.effectiveLength).to(equal(0))
            }

            it("with OutOfGas result for index=0") {
                let m = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 1, memoryLimit: 1024, hardFork: .Byzantium)

                _ = m.stack.push(value: U256(from: 33))
                _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(9))
            }

            it("check stack underflow errors is as expected") {
                let m1 = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, hardFork: .Byzantium)
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, hardFork: .Byzantium)
                _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack Int failure is as expected") {
                let m1 = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, hardFork: .Byzantium)
                _ = m1.stack.push(value: U256(from: 1))
                _ = m1.stack.push(value: U256(from: [1, 1, 0, 0]))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, hardFork: .Byzantium)
                _ = m2.stack.push(value: U256(from: [1, 1, 0, 0]))
                _ = m2.stack.push(value: U256(from: 1))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("activates at Byzantium before checking stack operands") {
                for fork in HardFork.allCases {
                    for hasOperands in [false, true] {
                        let m = TestMachine.machine(opcodes: [.REVERT], gasLimit: 0, memoryLimit: 32, hardFork: fork)
                        if hasOperands {
                            m.stackPush(value: .ZERO)
                            m.stackPush(value: .MAX)
                        }

                        m.evalLoop()

                        let expected: Machine.MachineStatus
                        if fork.rawValue < HardFork.Byzantium.rawValue {
                            expected = .Exit(.Error(.HardForkNotActive))
                            expect(m.stack.length).to(equal(hasOperands ? 2 : 0))
                        } else {
                            expected = hasOperands ? .Exit(.Revert) : .Exit(.Error(.StackUnderflow))
                            expect(m.stack.length).to(equal(0))
                        }
                        expect(m.machineStatus).to(equal(expected), description: "fork=\(fork), hasOperands=\(hasOperands)")
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.gas.memoryGas.numWords).to(equal(0))
                        expect(m.gas.memoryGas.gasCost).to(equal(0))
                        expect(m.memory.effectiveLength).to(equal(0))
                        expect(m.returnRange).to(equal(0 ..< 0))
                    }
                }
            }

            it("returns the exact nonempty memory slice across a word boundary") {
                let m = TestMachine.machine(opcode: .REVERT, gasLimit: 100)
                expect(m.memory.set(offset: 30, value: [0xAA, 0xBB, 0xCC, 0xDD], size: 4)).to(beSuccess())
                m.stackPush(value: U256(from: 3))
                m.stackPush(value: U256(from: 31))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Revert)))
                expect(m.returnRange).to(equal(31 ..< 34))
                expect(m.memory.get(offset: m.returnRange.lowerBound, size: m.returnRange.count)).to(equal([0xBB, 0xCC, 0xDD]))
                expect(m.gas.remaining).to(equal(94))
                expect(m.stack.length).to(equal(0))
            }

            it("Success") {
                let m = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, hardFork: .Byzantium)

                _ = m.stack.push(value: U256(from: 32))
                _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Revert)))
                expect(m.returnRange).to(equal(33 ..< 33 + 32))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(91))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(9))
            }
        }
    }
}
