import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticAddSpec: QuickSpec {
    override class func spec() {
        describe("overflowAdd") {
            context("when adding zero to zero") {
                it("returns zero without overflow") {
                    let a = U256.ZERO
                    let b = U256.ZERO
                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(U256.ZERO))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding zero to a non-zero number") {
                it("returns the same number without overflow") {
                    let a = U256(from: Array(repeating: UInt64(0xA), count: Int(U256.numberBase)))
                    let b = U256.ZERO
                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(a))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding zero to a MAX number") {
                it("returns the same number without overflow") {
                    let a = U256.MAX
                    let b = U256.ZERO
                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(a))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding two small numbers without carry") {
                it("returns correct sum without overflow") {
                    let a = U256(from: Array(repeating: UInt64(0xA), count: Int(U256.numberBase)))
                    let b = U256(from: Array(repeating: UInt64(0xE), count: Int(U256.numberBase)))
                    let expectedSum = U256(
                        from: Array(repeating: UInt64(0xA + 0xE), count: Int(U256.numberBase)))

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beFalse())
                }

                it("explicit sum operation returns correct sum without overflow") {
                    let a = U256(from: Array(repeating: UInt64(0xA), count: Int(U256.numberBase)))
                    let b = U256(from: Array(repeating: UInt64(0xE), count: Int(U256.numberBase)))
                    let expectedSum = U256(
                        from: Array(repeating: UInt64(0xA + 0xE), count: Int(U256.numberBase)))

                    let result = a + b

                    expect(result).to(equal(expectedSum))
                }

                it("explicit += operation returns correct sum without overflow") {
                    var a = U256(from: Array(repeating: UInt64(0xA), count: Int(U256.numberBase)))
                    let b = U256(from: Array(repeating: UInt64(0xE), count: Int(U256.numberBase)))
                    let expectedSum = U256(
                        from: Array(repeating: UInt64(0xA + 0xE), count: Int(U256.numberBase)))

                    a += b
                    let result = a

                    expect(result).to(equal(expectedSum))
                }
            }

            context("when adding two numbers with carry but no overflow") {
                it("returns correct sum with carry without overflow") {
                    let a = U256(from: [UInt64.max - 1, 0, 0, 0])
                    let b = U256(from: [2, 0, 0, 0])
                    let expectedSum = U256(from: [0, 1, 0, 0])

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beFalse())
                }

                it("returns correct sum with carry and overflow") {
                    let a = U256(from: [0, 0, 0, UInt64.max - 1])
                    let b = U256(from: [0, 0, 0, 2])
                    let expectedSum = U256(from: [0, 0, 0, 0])

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }

                it("explicit sum operation returns correct sum with carry without overflow") {
                    let a = U256(from: [0, 0, 0, UInt64.max - 1])
                    let b = U256(from: [0, 0, 0, 2])
                    let expectedSum = U256(from: [0, 0, 0, 0])

                    let result = a + b

                    expect(result).to(equal(expectedSum))
                }
            }

            context("when adding two maximum numbers causing overflow") {
                it("returns zero with overflow") {
                    let a = U256.MAX
                    let b = U256(from: [1, 0, 0, 0])
                    let expectedSum = U256.ZERO

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }
            }

            context("when adding two numbers resulting in multiple carries") {
                it("returns correct sum without overflow") {
                    let a = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max - 1])
                    let b = U256(from: [1, 0, 0, 0])
                    let expectedSum = U256(from: [0, 0, 0, UInt64.max])

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding numbers: (MAX-1) +1") {
                it("returns correct sum without overflow") {
                    let a = U256(
                        from: [UInt64](repeating: UInt64.max - 1, count: Int(U256.numberBase)))
                    let b = U256(from: [UInt64](repeating: 1, count: Int(U256.numberBase)))
                    let expectedSum = U256.MAX

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding two large numbers without overflow") {
                it("returns correct sum without overflow") {
                    let a = U256(from: [UInt64.max, UInt64.max - 3, UInt64.max - 3, UInt64.max - 4])
                    let b = U256(from: [1, 2, 3, 4])
                    let expectedSum = U256(from: [0, UInt64.max, UInt64.max, UInt64.max])

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beFalse())
                }
            }

            context("when adding to large number causing overflow") {
                it("returns correct sum with overflow for 4-element") {
                    let a = U256(from: [0, 0, 0, UInt64.max])
                    let b = U256(from: [0, 0, 0, 1])
                    let expectedSum = U256.ZERO

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }

                it("returns correct sum with overflow for 3-element") {
                    let a = U256(from: [0, 0, UInt64.max, UInt64.max - 2])
                    let b = U256(from: [0, 0, 1, 2])
                    let expectedSum = U256.ZERO

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }

                it("returns correct sum with overflow for 2-element") {
                    let a = U256(from: [0, UInt64.max, UInt64.max - 2, UInt64.max - 3])
                    let b = U256(from: [0, 1, 2, 3])
                    let expectedSum = U256.ZERO

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }

                it("returns correct sum with overflow for 1-element") {
                    let a = U256(from: [UInt64.max, UInt64.max - 2, UInt64.max - 3, UInt64.max - 4])
                    let b = U256(from: [1, 2, 3, 4])
                    let expectedSum = U256.ZERO

                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(expectedSum))
                    expect(overflow).to(beTrue())
                }
            }

            context("when adding maximum value and zero") {
                it("returns the maximum value without overflow") {
                    let a = U256.MAX
                    let b = U256.ZERO
                    let (result, overflow) = a.overflowAdd(b)

                    expect(result).to(equal(U256.MAX))
                    expect(overflow).to(beFalse())
                }
            }
        }
    }
}
