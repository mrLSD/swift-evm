@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class TransferSpec: QuickSpec {
    override class func spec() {
        describe("Transfer struct") {
            let addrSource = H160(from: [UInt8](repeating: 0x0A, count: 20))
            let addrTarget = H160(from: [UInt8](repeating: 0x0B, count: 20))
            let val = U256(from: 5000)

            context("initialization") {
                it("should correctly store source, target and value") {
                    let transfer = Transfer(source: addrSource, target: addrTarget, value: val)

                    expect(transfer.source).to(equal(addrSource))
                    expect(transfer.target).to(equal(addrTarget))
                    expect(transfer.value).to(equal(val))
                }
            }

            context("edge cases") {
                it("should handle zero transfer values") {
                    let transfer = Transfer(source: addrSource, target: addrTarget, value: .ZERO)

                    expect(transfer.value.isZero).to(beTrue())
                }

                it("should handle transfers between the same address") {
                    let transfer = Transfer(source: addrSource, target: addrSource, value: val)

                    expect(transfer.source).to(equal(transfer.target))
                    expect(transfer.value).to(equal(val))
                }

                it("should handle maximum U256 values") {
                    let transfer = Transfer(source: addrSource, target: addrTarget, value: .MAX)

                    expect(transfer.value).to(equal(U256.MAX))
                }
            }

            context("Value Semantics") {
                it("should be a value type and copied by value") {
                    let transfer1 = Transfer(source: addrSource, target: addrTarget, value: val)
                    var transfer2 = transfer1

                    transfer2 = Transfer(source: addrTarget, target: addrSource, value: .ZERO)

                    expect(transfer1.source).to(equal(addrSource))
                    expect(transfer2.source).to(equal(addrTarget))
                }
            }
        }
    }
}
