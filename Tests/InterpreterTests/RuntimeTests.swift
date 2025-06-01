
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class RuntimeSpec: QuickSpec {
    override class func spec() {
        describe("Runtime") {
            it("initializes ") {
                let context = Runtime.Context(target: H160.ZERO, sender: H160.ZERO, value: U256.ZERO)
                let _ = Runtime(code: [], data: [], gasLimit: 0, context: context, handler: TestHandler())
            }
        }
    }
}
