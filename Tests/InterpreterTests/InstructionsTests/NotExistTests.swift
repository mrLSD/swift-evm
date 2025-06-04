@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionNotExistSpec: QuickSpec {
    override class func spec() {
        describe("Instruction Not Exist (invalid opcode)") {
            it("Not existed opcode") {
                let m = Machine(data: [], code: [0xEF], gasLimit: 10, context: TestMachine.defaultContext(), handler: TestHandler())

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidOpcode(0xEF)))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
