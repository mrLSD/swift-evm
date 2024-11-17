@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionNotSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.NOT, gasLimit: 10)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.NOT, gasLimit: 2)

    override class func spec() {
        describe("Instruction NOT") {
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
