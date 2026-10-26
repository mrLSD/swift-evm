@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ExecutionStateSpec: QuickSpec {
    override class func spec() {
        describe("ExecutionState") {
            context("warm and cold storage slots") {
                it("tracks the full address and key independently of account warmth") {
                    let state = ExecutionState()
                    let address = TestHandler.address1
                    state.warm(address: address)
                    expect(state.isCold(address: address, index: .ZERO)).to(beTrue())

                    state.warm(address: address, index: .ZERO, isCold: false)
                    expect(state.isCold(address: address, index: .ZERO)).to(beTrue())

                    state.warm(address: address, index: .ZERO)
                    state.warm(address: address, index: .ZERO)
                    expect(state.accessed.storage.count).to(equal(1))
                    expect(state.isCold(address: address, index: .ZERO)).to(beFalse())
                    expect(state.isCold(address: address, index: .MAX)).to(beTrue())
                    expect(state.isCold(address: TestHandler.address2, index: .ZERO)).to(beTrue())

                    state.warm(address: TestHandler.address2, index: .MAX)
                    expect(state.isCold(address: TestHandler.address2)).to(beTrue())
                }

                it("inherits warm slots without changing parents or siblings") {
                    let parent = ExecutionState()
                    let child = ExecutionState()
                    let grandchild = ExecutionState()
                    let sibling = ExecutionState()
                    child.parent = parent
                    grandchild.parent = child
                    sibling.parent = parent
                    let address = TestHandler.address1
                    parent.warm(address: address, index: .ZERO)
                    expect(grandchild.isCold(address: address, index: .ZERO)).to(beFalse())
                    expect(grandchild.isCold(address: address, index: .MAX)).to(beTrue())

                    child.warm(address: address, index: .MAX)
                    expect(grandchild.isCold(address: address, index: .MAX)).to(beFalse())
                    expect(parent.isCold(address: address, index: .MAX)).to(beTrue())
                    expect(sibling.isCold(address: address, index: .MAX)).to(beTrue())
                    expect(grandchild.accessed.storage).to(beEmpty())
                }
            }

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
