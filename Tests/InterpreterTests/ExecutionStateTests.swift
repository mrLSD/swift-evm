@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ExecutionStateSpec: QuickSpec {
    override class func spec() {
        describe("ExecutionState") {
            context("warm and cold addresses") {
                it("warm address and check is cold") {
                    let addr1 = TestHandler.address1
                    let addr2 = TestHandler.address2

                    let state = ExecutionState()
                    expect(state.isCold(address: addr1)).to(beTrue())
                    expect(state.isCold(address: addr2)).to(beTrue())

                    state.warm(address: addr1)
                    expect(state.isCold(address: addr1)).to(beFalse())
                    expect(state.isCold(address: addr2)).to(beTrue())
                }

                it("warm address with additional param") {
                    let addr1 = TestHandler.address1

                    let state = ExecutionState()
                    expect(state.isCold(address: addr1)).to(beTrue())

                    state.warm(address: addr1, isCold: false)
                    expect(state.isCold(address: addr1)).to(beTrue())

                    state.warm(address: addr1, isCold: true)
                    expect(state.isCold(address: addr1)).to(beFalse())
                }
            }
        }
    }
}
