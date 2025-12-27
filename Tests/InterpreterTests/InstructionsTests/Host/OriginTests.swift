@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionOriginSpec: QuickSpec {
    override class func spec() {
        describe("Instruction ORIGIN") {
            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.ORIGIN, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                let m = TestMachine.machine(opcode: Opcode.ORIGIN, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(10))
            }

            it("Successful execution") {
                let context = Machine.Context(targetAddress: TestHandler.address1,
                                              callerAddress: TestHandler.address2,
                                              callValue: U256.ZERO)
                let m = TestMachine.machine(opcode: Opcode.ORIGIN, gasLimit: 10, context: context, hardFork: .latest())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = try! m.stack.popH256().get().toH160()
                expect(result).to(equal(TestHandler.address1))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }
        }
    }
}
