
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class RuntimeSpec: QuickSpec {
    override class func spec() {
        describe("Runtime") {
            it("initializes") {
                let context = TestMachine.defaultContext()
                let runtime = Runtime(code: [], data: [], gasLimit: 0, context: context, state: ExecutionState(), handler: TestHandler())
                // Verify initial state
                expect(runtime.machine.data).to(beEmpty())
                expect(runtime.machine.code).to(beEmpty())
                expect(runtime.machine.gas.remaining).to(equal(0))
            }
        }
    }
}
