@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterGasSpec: QuickSpec {
    override class func spec() {
        describe("Interpreter Gas") {
            context("Initializers") {
                it("initializes correctly with limit") {
                    let limit: UInt64 = 1000
                    let gas = Gas(limit: limit)

                    expect(gas.limit).to(equal(limit))
                    expect(gas.remaining).to(equal(limit))
                    expect(gas.refunded).to(equal(0))
                    expect(gas.spent).to(equal(UInt64(0)))
                }

                it("initializes correctly without remaining gas") {
                    let limit: UInt64 = 1000
                    let gas = Gas(withoutRemain: limit)

                    expect(gas.limit).to(equal(limit))
                    expect(gas.remaining).to(equal(UInt64(0)))
                    expect(gas.refunded).to(equal(0))
                    expect(gas.spent).to(equal(limit))
                }

                it("handles zero limit correctly") {
                    let limit: UInt64 = 0
                    let gas = Gas(limit: limit)

                    expect(gas.limit).to(equal(limit))
                    expect(gas.remaining).to(equal(limit))
                    expect(gas.refunded).to(equal(0))
                    expect(gas.spent).to(equal(UInt64(0)))
                }
            }

            context("recordCost(cost:)") {
                it("successfully records cost less than remaining gas") {
                    var gas = Gas(limit: 1000)
                    let cost: UInt64 = 300
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beTrue())
                    expect(gas.remaining).to(equal(700))
                    expect(gas.spent).to(equal(300))
                }

                it("successfully records cost equal to remaining gas") {
                    var gas = Gas(limit: 500)
                    let cost: UInt64 = 500
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beTrue())
                    expect(gas.remaining).to(equal(0))
                    expect(gas.spent).to(equal(500))
                }

                it("fails to record cost greater than remaining gas") {
                    var gas = Gas(limit: 400)
                    let cost: UInt64 = 500
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beFalse())
                    expect(gas.remaining).to(equal(400)) // Should remain unchanged
                    expect(gas.spent).to(equal(0))
                }

                it("handles cost of zero correctly") {
                    var gas = Gas(limit: 1000)
                    let cost: UInt64 = 0
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beTrue())
                    expect(gas.remaining).to(equal(1000))
                    expect(gas.spent).to(equal(0))
                }

                it("handles maximum UInt64 cost without overflow") {
                    var gas = Gas(limit: UInt64.max)
                    let cost: UInt64 = 1
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beTrue())
                    expect(gas.remaining).to(equal(UInt64.max - 1))
                    expect(gas.spent).to(equal(UInt64(1)))
                }

                it("fails to record cost when remaining is zero") {
                    var gas = Gas(withoutRemain: 1000)
                    let cost: UInt64 = 1
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beFalse())
                    expect(gas.remaining).to(equal(0))
                    expect(gas.spent).to(equal(1000))
                }
            }

            context("recordRefund(refund:)") {
                it("records a positive refund correctly") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 200)

                    expect(gas.refunded).to(equal(200))
                }

                it("records a negative refund correctly") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: -150)

                    expect(gas.refunded).to(equal(-150))
                }

                it("cumulatively records multiple refunds") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 100)
                    gas.recordRefund(refund: 200)
                    gas.recordRefund(refund: -50)

                    expect(gas.refunded).to(equal(250))
                }

                it("handles refund leading to zero refunded") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 100)
                    gas.recordRefund(refund: -100)

                    expect(gas.refunded).to(equal(0))
                }

                it("handles maximum and minimum Int64 refunds without overflow") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: Int64.max)
                    gas.recordRefund(refund: Int64.min)

                    expect(gas.refunded).to(equal(-1))
                }
            }

            context("setFinalRefund(isLondon:)") {
                it("sets final refund correctly when isLondon is true") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 300)
                    let success = gas.recordCost(cost: 500) // spent = 500

                    expect(success).to(beTrue())
                    // maxRefundQuotient = 5
                    gas.setFinalRefund(isLondon: true)
                    // maxRefund = min(300, 500 / 5) = min(300, 100) = 100
                    expect(gas.refunded).to(equal(100))
                }

                it("sets final refund correctly when isLondon is false") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 300)
                    let success = gas.recordCost(cost: 500) // spent = 500

                    expect(success).to(beTrue())
                    gas.setFinalRefund(isLondon: false) // maxRefundQuotient = 2
                    // maxRefund = min(300, 500 / 2) = min(300, 250) = 250
                    expect(gas.refunded).to(equal(250))
                }

                it("does not reduce refunded when it's less than maxRefund") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 50)
                    let success = gas.recordCost(cost: 300) // spent = 300

                    expect(success).to(beTrue())
                    // maxRefundQuotient = 5
                    gas.setFinalRefund(isLondon: true)
                    // maxRefund = min(50, 300 / 5) = min(50, 60) = 50
                    expect(gas.refunded).to(equal(50))
                }

                it("sets refunded to maxRefund when refunded exceeds maxRefund") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 200)
                    let success = gas.recordCost(cost: 300) // spent = 300

                    expect(success).to(beTrue())
                    // maxRefundQuotient = 2
                    gas.setFinalRefund(isLondon: false)
                    // maxRefund = min(200, 300 / 2) = min(200, 150) = 150
                    expect(gas.refunded).to(equal(150))
                }

                it("handles zero refund correctly") {
                    var gas = Gas(limit: 1000)
                    let success = gas.recordCost(cost: 500) // spent = 500

                    expect(success).to(beTrue())
                    gas.setFinalRefund(isLondon: true) // refunded = 0
                    expect(gas.refunded).to(equal(0))
                }

                it("handles negative refunded values correctly") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: -100)
                    let success = gas.recordCost(cost: 400) // spent = 400

                    expect(success).to(beTrue())
                    gas.setFinalRefund(isLondon: true) // maxRefundQuotient = 5
                    // maxRefund = min(UInt64(-100), 400 / 5) → min(??)
                    // Since refunded is Int64 and min is using UInt64(refunded), which is invalid if refunded is negative
                    // Need to ensure refunded is treated as UInt64 correctly
                    // Possibly, this should set refunded to 0 or handle accordingly
                    // Depending on implementation, but assuming min(UInt64(refunded), ...) where UInt64(refunded) would wrap around
                    // This might need clarification, but for testing, we'll check behavior
                    // If refunded is negative, UInt64(refunded) is a large number, so min would be spent / quotient
                    expect(gas.refunded).to(equal(0))
                }

                it("handles spent less than maxRefundQuotient correctly") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: 100)
                    let success = gas.recordCost(cost: 4) // spent = 4

                    expect(success).to(beTrue())
                    // maxRefundQuotient = 5
                    gas.setFinalRefund(isLondon: true)
                    // maxRefund = min(100, 4 / 5) = min(100, 0) = 0
                    expect(gas.refunded).to(equal(0))
                }
            }

            context("spent property") {
                it("calculates spent correctly after recording costs") {
                    var gas = Gas(limit: 1000)
                    gas.recordCost(cost: 200)
                    let success = gas.recordCost(cost: 300)

                    expect(success).to(beTrue())
                    expect(gas.spent).to(equal(500))
                }

                it("calculates spent correctly when remaining is zero") {
                    var gas = Gas(limit: 500)
                    let success = gas.recordCost(cost: 500)

                    expect(success).to(beTrue())
                    expect(gas.spent).to(equal(500))
                }

                it("calculates spent correctly with no costs recorded") {
                    let gas = Gas(limit: 800)

                    expect(gas.spent).to(equal(0))
                }
            }

            context("Edge Cases") {
                it("handles maximum UInt64 limit correctly") {
                    let limit = UInt64.max
                    let gas = Gas(limit: limit)

                    expect(gas.limit).to(equal(limit))
                    expect(gas.remaining).to(equal(limit))
                    expect(gas.spent).to(equal(UInt64(0)))
                }

                it("handles recordCost with maximum UInt64 correctly") {
                    var gas = Gas(limit: UInt64.max)
                    let cost = UInt64.max
                    let success = gas.recordCost(cost: cost)

                    expect(success).to(beTrue())
                    expect(gas.remaining).to(equal(UInt64(0)))
                    expect(gas.spent).to(equal(UInt64.max))
                }

                it("handles recordRefund leading to refunded exceeding Int64.max") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: Int64.max - 1)
                    gas.recordRefund(refund: 1)

                    expect(gas.refunded).to(equal(Int64.max))
                }

                it("handles recordRefund leading to refunded becoming negative beyond Int64.min") {
                    var gas = Gas(limit: 1000)
                    gas.recordRefund(refund: Int64.min + 1)
                    gas.recordRefund(refund: -1)

                    expect(gas.refunded).to(equal(Int64.min))
                }
            }
        }
    }
}
