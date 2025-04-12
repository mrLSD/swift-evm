@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMachineTestsSpec: QuickSpec {
    override class func spec() {
        describe("Machine tests") {
            it("Int or fail tests") {
                let m1 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res1 = m1.getIntOrFail(U256(from: [1, 1, 0, 0]))
                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(res1).to(beNil())

                let m2 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res2 = m2.getIntOrFail(U256(from: 10))
                expect(m2.machineStatus).to(equal(.NotStarted))
                expect(res2).to(equal(10))
            }
        }
    }
}
