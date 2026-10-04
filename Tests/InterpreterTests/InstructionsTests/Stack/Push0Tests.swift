@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPush0Spec: QuickSpec {
    override class func spec() {
        describe("Instruction PUSH0") {
            it("activates at Shanghai across all supported forks") {
                for fork in HardFork.allCases {
                    let m = TestMachine.machine(opcodes: [.PUSH0], gasLimit: 10, memoryLimit: 32, hardFork: fork)

                    m.evalLoop()

                    if fork.rawValue < HardFork.Shanghai.rawValue {
                        expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: "fork=\(fork)")
                        expect(m.gas.remaining).to(equal(10))
                        expect(m.stack.length).to(equal(0))
                    } else {
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "fork=\(fork)")
                        expect(m.gas.remaining).to(equal(8))
                        expect(m.stack.length).to(equal(1))
                        expect(m.stackPop()).to(equal(U256.ZERO))
                    }
                }
            }

            it("checks activation before stack and gas requirements") {
                let m = TestMachine.machine(opcodes: [.PUSH0], gasLimit: 0, memoryLimit: 32, hardFork: .Paris)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.length).to(equal(0))
            }

            it("PUSH 0") {
                let m = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 10)

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10 - GasConstant.BASE))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                let m = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
