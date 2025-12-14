import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticSubSpec: QuickSpec {
    override class func spec() {
        describe("overflowSub") {
            context("when subtracting without borrow or overflow") {
                it("should return the correct result and no overflow") {
                    let selfNumber = U256(from: [10, 20, 30, 40])
                    let value = U256(from: [5, 10, 15, 20])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(U256(from: [5, 10, 15, 20])))
                    expect(overflow).to(beFalse())

                    expect(selfNumber-value).to(equal(result))
                }

                it("success substitution works for a -= operation") {
                    var a = U256(from: 5)
                    let b = U256(from: 3)
                    a -= b
                    let result = a

                    expect(result).to(equal(U256(from: 2)))
                }
            }

            context("when subtraction requires a borrow but no overflow") {
                it("handles borrow correctly without setting overflow") {
                    let selfNumber = U256(from: [0, 1, 0, 0])
                    let value = U256(from: [1, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    // Expected result:
                    // Byte 0: 0 - 1 = UInt64.max (borrow)
                    // Byte 1: 1 - 0 - 1(borrow) = 0
                    // Byte 2: 0 - 0 = 0
                    // Byte 3: 0 - 0 = 0
                    expect(result).to(equal(U256(from: [UInt64.max, 0, 0, 0])))
                    expect(overflow).to(beFalse())
                }
            }

            context("when subtraction results in overflow") {
                it("sets overflow to true when self < value") {
                    let selfNumber = U256(from: [1, 0, 0, 0])
                    let value = U256(from: [2, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    // Expected result:
                    // Byte 0: 1 - 2 = UInt64.max (borrow)
                    // Byte 1: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    // Byte 2: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    // Byte 3: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    expect(result).to(equal(U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])))
                    expect(overflow).to(beTrue())
                }
            }

            context("when subtraction involves multiple borrows across several words") {
                it("correctly propagates borrows and sets no overflow") {
                    let selfNumber = U256(from: [0, 0, 0, 1])
                    let value = U256(from: [1, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    // Expected result:
                    // Byte 0: 0 - 1 = UInt64.max (borrow)
                    // Byte 1: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    // Byte 2: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    // Byte 3: 1 - 0 - 1(borrow) = 0
                    expect(result).to(equal(U256(from: [UInt64.max, UInt64.max, UInt64.max, 0])))
                    expect(overflow).to(beFalse())
                }
            }

            context("when subtracting zero from self") {
                it("returns self unchanged and no overflow") {
                    let selfNumber = U256(from: [5, 10, 15, 20])
                    let value = U256(from: [0, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(selfNumber))
                    expect(overflow).to(beFalse())
                }
            }

            context("when self is zero and subtracting zero") {
                it("returns zero and no overflow") {
                    let selfNumber = U256(from: [0, 0, 0, 0])
                    let value = U256(from: [0, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(U256(from: [0, 0, 0, 0])))
                    expect(overflow).to(beFalse())
                }
            }

            context("when self equals value") {
                it("returns zero and no overflow") {
                    let selfNumber = U256(from: [7, 14, 21, 28])
                    let value = U256(from: [7, 14, 21, 28])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(U256(from: [0, 0, 0, 0])))
                    expect(overflow).to(beFalse())
                }
            }

            context("when only the highest word subtraction underflows") {
                it("sets overflow when the highest word subtraction underflows") {
                    let selfNumber = U256(from: [5, 10, 15, 20])
                    let value = U256(from: [5, 10, 16, 20])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    // Expected result:
                    // Byte 0: 5 - 5 = 0
                    // Byte 1: 10 - 10 = 0
                    // Byte 2: 15 - 16 = UInt64.max (borrow)
                    // Byte 3: 20 - 20 - 1(borrow) = UInt64.max (borrow, causes overflow)
                    expect(result).to(equal(U256(from: [0, 0, UInt64.max, UInt64.max])))
                    expect(overflow).to(beTrue())
                }
            }

            context("when subtraction results in all words underflowing") {
                it("correctly sets overflow") {
                    let selfNumber = U256(from: [0, 0, 0, 0])
                    let value = U256(from: [1, 1, 1, 1])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(U256(from: [UInt64.max, UInt64.max-1, UInt64.max-1, UInt64.max-1])))
                    expect(overflow).to(beTrue())
                }
            }

            context("when self has maximum possible values and subtracting zero") {
                it("returns self unchanged and no overflow") {
                    let maxUInt64 = UInt64.max
                    let selfNumber = U256(from: [maxUInt64, maxUInt64, maxUInt64, maxUInt64])
                    let value = U256(from: [0, 0, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    expect(result).to(equal(selfNumber))
                    expect(overflow).to(beFalse())
                }
            }

            context("when subtraction causes multiple borrows with overflow") {
                it("handles multiple borrows correctly and sets overflow to true") {
                    let selfNumber = U256(from: [10, 0, 0, 0])
                    let value = U256(from: [5, 1, 0, 0])
                    let (result, overflow) = selfNumber.overflowSub(value)

                    // Expected result:
                    // Byte 0: 10 - 5 = 5
                    // Byte 1: 0 - 1 = UInt64.max (borrow)
                    // Byte 2: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    // Byte 3: 0 - 0 - 1(borrow) = UInt64.max (borrow)
                    expect(result).to(equal(U256(from: [5, UInt64.max, UInt64.max, UInt64.max])))
                    expect(overflow).to(beTrue())
                }
            }
        }
    }
}
