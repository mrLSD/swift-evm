import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticMacSpec: QuickSpec {
    override class func spec() {
        describe("mac operation") {
            context("no carry") {
                it("returns correct result") {
                    var lhs: UInt64 = 10
                    let a: UInt64 = 2
                    let b: UInt64 = 3
                    let c: UInt64 = 4

                    let result = U256.mac(&lhs, a, b, c)

                    // Expected product: a * b = 6
                    // sumLow1 = 6 + 4 = 10 (no carry)
                    // sumLow2 = 10 + 10 = 20 (no carry)
                    // lhs is updated to 20
                    // Returned value: productHigh (0) + 0 + 0 = 0
                    expect(lhs).to(equal(20))
                    expect(result).to(equal(0))
                }
            }

            context("carry1 only") {
                it("returns correct result") {
                    var lhs: UInt64 = 5
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = 1
                    let c: UInt64 = 1

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = UInt64.max * 1 = UInt64.max
                    // productHigh = 0
                    // productLow = UInt64.max
                    // sumLow1 = UInt64.max + 1 = 0 (overflow), carry1 = true
                    // sumLow2 = 0 + 5 = 5 (no overflow), carry2 = false
                    // lhs is updated to 5
                    // Returned value: 0 + 1 + 0 = 1
                    expect(lhs).to(equal(5))
                    expect(result).to(equal(1))
                }
            }

            context("carry2 only") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max
                    let a: UInt64 = 2
                    let b: UInt64 = 3
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = 6, productHigh = 0, productLow = 6
                    // sumLow1 = 6 + UInt64.max = 5 (overflow), carry1 = true
                    // sumLow2 = 5 + UInt64.max = 4 (overflow), carry2 = true
                    // lhs is updated to 4
                    // Returned value: 0 + 1 + 1 = 2
                    expect(lhs).to(equal(4))
                    expect(result).to(equal(2))
                }
            }

            context("both carries") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = 2
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = (2^64 -1) * 2 = 2^65 - 2
                    // productHigh = 1
                    // productLow = UInt64.max - 1
                    // sumLow1 = (UInt64.max - 1) + UInt64.max = 2^64 - 3 (overflow), carry1 = true
                    // sumLow2 = (2^64 -3) + UInt64.max = 2^65 - 4 (overflow), carry2 = true
                    // lhs is updated to UInt64.max - 3
                    // Returned value: 1 + 1 + 1 = 3
                    expect(lhs).to(equal(UInt64.max - 3))
                    expect(result).to(equal(3))
                }
            }

            context("sum low1 equals max") {
                it("returns correct result") {
                    var lhs: UInt64 = 0
                    let a: UInt64 = 1
                    let b: UInt64 = UInt64.max
                    let c: UInt64 = 0

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = UInt64.max
                    // productHigh = 0
                    // productLow = UInt64.max
                    // sumLow1 = UInt64.max + 0 = UInt64.max, carry1 = false
                    // sumLow2 = UInt64.max + 0 = UInt64.max, carry2 = false
                    // lhs is updated to UInt64.max
                    // Returned value: 0 + 0 + 0 = 0
                    expect(lhs).to(equal(UInt64.max))
                    expect(result).to(equal(0))
                }
            }

            context("sum low2 equals max") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max - 10
                    let a: UInt64 = 1
                    let b: UInt64 = 1
                    let c: UInt64 = 10

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = 1
                    // productHigh = 0
                    // productLow = 1
                    // sumLow1 = 1 + 10 = 11, carry1 = false
                    // sumLow2 = 11 + (UInt64.max - 10) = UInt64.max +1 = 0 (overflow), carry2 = true
                    // lhs is updated to 0
                    // Returned value: 0 + 0 + 1 = 1
                    expect(lhs).to(equal(0))
                    expect(result).to(equal(1))
                }
            }

            context("all zeros") {
                it("returns correct result") {
                    var lhs: UInt64 = 0
                    let a: UInt64 = 0
                    let b: UInt64 = 0
                    let c: UInt64 = 0

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = 0
                    // productHigh = 0
                    // productLow = 0
                    // sumLow1 = 0 + 0 = 0, carry1 = false
                    // sumLow2 = 0 + 0 = 0, carry2 = false
                    // lhs is updated to 0
                    // Returned value: 0 + 0 + 0 = 0
                    expect(lhs).to(equal(0))
                    expect(result).to(equal(0))
                }
            }

            context("large numbers no carry") {
                it("returns correct result") {
                    var lhs: UInt64 = 1_000_000_000_000
                    let a: UInt64 = 1_000_000
                    let b: UInt64 = 1_000_000
                    let c: UInt64 = 1_000_000

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = 1_000_000 * 1_000_000 = 1_000_000_000_000
                    // productHigh = 0
                    // productLow = 1_000_000_000_000
                    // sumLow1 = 1_000_000_000_000 + 1_000_000 = 1_000_001_000_000 (no carry)
                    // sumLow2 = 1_000_001_000_000 + 1_000_000_000_000 = 2_000_001_000_000 (no carry)
                    // lhs is updated to 2_000_001_000_000
                    // Returned value: 0 + 0 + 0 = 0
                    expect(lhs).to(equal(2_000_001_000_000))
                    expect(result).to(equal(0))
                }
            }

            context("carry1 overflow") {
                it("returns correct result") {
                    var lhs: UInt64 = 0
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = 1
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = UInt64.max
                    // productHigh = 0
                    // productLow = UInt64.max
                    // sumLow1 = UInt64.max + UInt64.max = UInt64.max - 1 (overflow), carry1 = true
                    // sumLow2 = UInt64.max - 1 + 0 = UInt64.max - 1 (no overflow), carry2 = false
                    // lhs is updated to UInt64.max - 1
                    // Returned value: 0 + 1 + 0 = 1
                    expect(lhs).to(equal(UInt64.max - 1))
                    expect(result).to(equal(1))
                }
            }

            context("carry2 overflow only") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max
                    let a: UInt64 = 0
                    let b: UInt64 = 0
                    let c: UInt64 = 1

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = 0
                    // productHigh = 0
                    // productLow = 0
                    // sumLow1 = 0 + 1 = 1, carry1 = false
                    // sumLow2 = 1 + UInt64.max = 0 (overflow), carry2 = true
                    // lhs is updated to 0
                    // Returned value: 0 + 0 + 1 = 1
                    expect(lhs).to(equal(0))
                    expect(result).to(equal(1))
                }
            }

            context("carry1 only with max inputs") {
                it("returns correct result") {
                    var lhs: UInt64 = 0
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = UInt64.max
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = (2^64 -1) * (2^64 -1) = 2^128 - 2^65 + 1
                    // productHigh = 2^64 - 2 (only considering UInt64, productHigh = a * b >> 64)
                    // However, in Swift, multipliedFullWidth(by:) for UInt64 returns (high: UInt64, low: UInt64)
                    // Calculating:
                    // productLow = UInt64.max * UInt64.max = 1
                    // productHigh = UInt64.max -1
                    // sumLow1 = 1 + UInt64.max = 0 (overflow), carry1 = true
                    // sumLow2 = 0 + 0 = 0 (no overflow), carry2 = false
                    // lhs is updated to 0
                    // Returned value: (UInt64.max -1) + 1 + 0 = UInt64.max
                    expect(lhs).to(equal(0))
                    expect(result).to(equal(UInt64.max))
                }
            }

            context("carry2 only with max inputs") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = 1
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = UInt64.max * 1 = UInt64.max
                    // productHigh = 0
                    // productLow = UInt64.max
                    // sumLow1 = UInt64.max + UInt64.max = UInt64.max -1 (overflow), carry1 = true
                    // sumLow2 = UInt64.max -1 + UInt64.max = UInt64.max -1 + UInt64.max = (UInt64.max -1) + UInt64.max = UInt64.max -2 (overflow), carry2 = true
                    // lhs is updated to UInt64.max - 2
                    // Returned value: 0 +1 +1 = 2
                    expect(lhs).to(equal(UInt64.max - 2))
                    expect(result).to(equal(2))
                }
            }

            context("both carries with max inputs") {
                it("returns correct result") {
                    var lhs: UInt64 = UInt64.max
                    let a: UInt64 = UInt64.max
                    let b: UInt64 = UInt64.max
                    let c: UInt64 = UInt64.max

                    let result = U256.mac(&lhs, a, b, c)

                    // a * b = (2^64 -1)^2 = 2^128 - 2*2^64 +1
                    // productHigh = UInt64.max -1
                    // productLow = 1
                    // sumLow1 = 1 + UInt64.max = 0 (overflow), carry1 = true
                    // sumLow2 = 0 + UInt64.max = UInt64.max (no overflow), carry2 = false
                    // lhs is updated to UInt64.max
                    // Returned value: (UInt64.max -1) +1 +0 = UInt64.max
                    expect(lhs).to(equal(UInt64.max))
                    expect(result).to(equal(UInt64.max))
                }
            }
        }
    }
}
