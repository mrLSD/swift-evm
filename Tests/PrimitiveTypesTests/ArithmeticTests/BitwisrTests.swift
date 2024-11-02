import Nimble
import Quick

@testable import PrimitiveTypes

final class BitwiseSpec: QuickSpec {
    override class func spec() {
        describe("Bitwise") {
            it("bitwise Not") {
                let a = U256(from: [1, 2, 3, 4])
                let result = ~a
                let expected = U256(from: [UInt64.max - 1, UInt64.max - 2, UInt64.max - 3, UInt64.max - 4])

                expect(result).to(equal(expected))
            }

            it("bitwise And") {
                let a = U256(from: [1, 2, 3, 4])
                let b = U256(from: [4, 3, 2, 1])
                let result = a & b
                let expected = U256(from: [0, 2, 2, 0])

                expect(result).to(equal(expected))
            }

            it("bitwise Or") {
                let a = U256(from: [1, 2, 3, 4])
                let b = U256(from: [4, 3, 2, 1])
                let result = a | b
                let expected = U256(from: [5, 3, 3, 5])

                expect(result).to(equal(expected))
            }
        }
    }
}
