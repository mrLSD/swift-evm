
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSelfbalanceSpec: QuickSpec {
    override class func spec() {
        describe("Instruction SELFBALANCE") {
            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.SELFBALANCE, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                let m = TestMachine.machine(opcode: Opcode.SELFBALANCE, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(5))
            }

            it("Successful Istanbul hard fork") {
                let context = Machine.Context(targetAddress: TestHandler.address1,
                                              callerAddress: TestHandler.address2,
                                              callValue: U256.ZERO)
                let m = TestMachine.machine(opcode: Opcode.SELFBALANCE, gasLimit: 10, context: context, hardFork: .Istanbul)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(5))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })
            }

            it("Fail Constantinople hard fork") {
                let context = Machine.Context(targetAddress: TestHandler.address1,
                                              callerAddress: TestHandler.address2,
                                              callValue: U256.ZERO)
                let m = TestMachine.machine(opcode: Opcode.SELFBALANCE, gasLimit: 10, context: context, hardFork: .Constantinople)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
