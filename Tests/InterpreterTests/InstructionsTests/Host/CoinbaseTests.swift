@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCoinbaseSpec: QuickSpec {
    override class func spec() {
        describe("Instruction COINBASE") {
            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.COINBASE, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                let m = TestMachine.machine(opcode: Opcode.COINBASE, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
            }

            it("Successful execution") {
                let context = Machine.Context(targetAddress: TestHandler.address1,
                                              callerAddress: TestHandler.address3,
                                              callValue: U256.ZERO)
                let m = TestMachine.machine(opcode: Opcode.COINBASE, gasLimit: 10, context: context, hardFork: .latest())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.popH256()
                expect(result).to(beSuccess { value in
                    let address = value.toH160()
                    // Value from the Handler's coinbase()
                    expect(address).to(equal(TestHandler.address2))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }
        }
    }
}
