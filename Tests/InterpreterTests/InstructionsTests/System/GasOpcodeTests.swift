@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionGasSpec: QuickSpec {
    override class func spec() {
        describe("Instruction GAS") {
            it("remaining gas after instruction cost") {
                let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(1))
                expect(m.stack.peek(indexFromTop: 0)).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 8)))
                })
                expect(m.gas.remaining).to(equal(8))
                expect(m.pc).to(equal(1))
            }

            it("with exactly enough gas") {
                let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: 2)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.pc).to(equal(1))
            }

            it("with OutOfGas result") {
                for gasLimit: UInt64 in [0, 1] {
                    let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: gasLimit)
                    expect(m.stack.push(value: U256(from: 5))).to(beSuccess())
                    let description = "gas limit \(gasLimit)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: description)
                    expect(m.stack.data).to(equal([U256(from: 5)]), description: description)
                    expect(m.gas.remaining).to(equal(gasLimit), description: description)
                    expect(m.pc).to(equal(0), description: description)
                }
            }

            it("preserves all 64 bits of remaining gas") {
                let cases: [(UInt64, UInt64)] = [
                    (0x1_0000_0002, 0x1_0000_0000),
                    (0x8000_0000_0000_0002, 0x8000_0000_0000_0000),
                    (UInt64.max, 0xffff_ffff_ffff_fffd)
                ]
                for (gasLimit, remaining) in cases {
                    let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: gasLimit)
                    let description = "gas limit \(gasLimit)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: description)
                    expect(m.stack.data).to(equal([U256(from: remaining)]), description: description)
                    expect(m.gas.remaining).to(equal(remaining), description: description)
                    expect(m.pc).to(equal(1), description: description)
                }
            }

            it("reads the updated gas on each step") {
                let m = TestMachine.machine(opcodes: [Opcode.GAS, Opcode.GAS], gasLimit: 10)
                m.machineStatus = .Continue

                m.step()

                expect(m.machineStatus).to(equal(.Continue))
                expect(m.stack.data).to(equal([U256(from: 8)]))
                expect(m.gas.remaining).to(equal(8))
                expect(m.pc).to(equal(1))

                m.step()

                expect(m.machineStatus).to(equal(.Continue))
                expect(m.stack.data).to(equal([U256(from: 8), U256(from: 6)]))
                expect(m.gas.remaining).to(equal(6))
                expect(m.pc).to(equal(2))
            }

            it("stops when a subsequent GAS runs out of gas") {
                let m = TestMachine.machine(opcodes: [Opcode.GAS, Opcode.GAS, Opcode.POP], gasLimit: 3)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.data).to(equal([U256(from: 1)]))
                expect(m.gas.remaining).to(equal(1))
                expect(m.pc).to(equal(1))
            }

            it("includes previous opcode and memory expansion costs") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0xab, Opcode.PUSH1.rawValue, 0,
                                                      Opcode.MSTORE.rawValue, Opcode.GAS.rawValue], gasLimit: 100)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                // Two PUSH1s, MSTORE, one memory word and GAS cost 3 + 3 + 3 + 3 + 2.
                expect(m.stack.data).to(equal([U256(from: 86)]))
                expect(m.gas.remaining).to(equal(86))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.memory.getWord(offset: 0)).to(equal(U256(from: 0xab)))
                expect(m.pc).to(equal(6))
            }

            it("does not include gas refunds") {
                for refund: Int64 in [-5, 5] {
                    let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: 10)
                    m.gas.recordRefund(refund: refund)
                    let description = "refund \(refund)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: description)
                    expect(m.stack.data).to(equal([U256(from: 8)]), description: description)
                    expect(m.gas.remaining).to(equal(8), description: description)
                    expect(m.gas.refunded).to(equal(refund), description: description)
                    expect(m.pc).to(equal(1), description: description)
                }
            }

            it("fills the last stack slot without changing existing values") {
                let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: 10)
                for i in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                }
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(original + [U256(from: 8)]))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
                expect(m.pc).to(equal(1))
            }

            it("check stack overflow before charging gas") {
                for gasLimit: UInt64 in [0, 1, 2, 10] {
                    let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: gasLimit)
                    for i in 0 ..< m.stack.limit {
                        expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                    }
                    let original = m.stack.data
                    let description = "gas limit \(gasLimit)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))), description: description)
                    expect(m.stack.data).to(equal(original), description: description)
                    expect(m.gas.remaining).to(equal(gasLimit), description: description)
                    expect(m.pc).to(equal(0), description: description)
                }
            }

            it("is available in every hard fork") {
                for hardFork in HardFork.allCases {
                    let m = TestMachine.machine(opcode: Opcode.GAS, gasLimit: 10,
                                                context: TestMachine.defaultContext(), hardFork: hardFork)
                    let description = "hard fork \(hardFork)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: description)
                    expect(m.stack.data).to(equal([U256(from: 8)]), description: description)
                    expect(m.gas.remaining).to(equal(8), description: description)
                    expect(m.pc).to(equal(1), description: description)
                }
            }
        }
    }
}
