@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionIsZeroSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.ISZERO, gasLimit: 10)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.ISZERO, gasLimit: 2)

    override class func spec() {
        describe("Instruction ISZERO") {
            it("check stack") {
                var m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m1 = Self.machine
                let _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
