@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MSizeSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.MSIZE, gasLimit: 1)

    override class func spec() {
        describe("Instruction MSIZE") {
            it("with OutOfGas result for index=0") {
                var m = Self.machineLowGas

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }
        }
    }
}
