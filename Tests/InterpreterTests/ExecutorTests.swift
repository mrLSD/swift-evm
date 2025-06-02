@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ExecutorSpec: QuickSpec {
    override class func spec() {
        describe("Executor") {
            it("initializes ") {
                let state = ExecutionState()
                let e = Executor(state: state)
                e.execute()
            }
        }
    }
}
