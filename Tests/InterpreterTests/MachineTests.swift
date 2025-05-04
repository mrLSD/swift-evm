@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMachineTestsSpec: QuickSpec {
    override class func spec() {
        describe("Machine tests") {
            it("UInt or fail tests") {
                var m1 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res1 = m1.getUintOrFail(U256(from: [1, 1, 0, 0]))
                expect(m1.machineStatus).to(equal(.Exit(.Error(.UIntOverflow))))
                expect(res1).to(beNil())

                var m2 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res2 = m2.getUintOrFail(U256(from: 10))
                expect(m2.machineStatus).to(equal(.NotStarted))
                expect(res2).to(equal(10))
            }
        }
    }
}
