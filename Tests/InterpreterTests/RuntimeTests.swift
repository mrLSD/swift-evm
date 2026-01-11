
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class RuntimeSpec: QuickSpec {
    override class func spec() {
        describe("Runtime") {
            it("initializes") {
                let context = TestMachine.defaultContext()
                let _ = Runtime(code: [], data: [], gasLimit: 0, context: context, state: ExecutionState(), handler: TestHandler())
            }
        }
    }
}
