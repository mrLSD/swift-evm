import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticMulSpec: QuickSpec {
    override class func spec() {
        describe("overflowMul operation") {
            context("without overflow") {
                it("multiplying by zero") {
                    let a = U256(from: [1, 2, 3, 4])
                    let b = U256(from: [0, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    expect(isOverflow).to(beFalse())
                }

                it("success multiplying *= operation") {
                    var a = U256(from: 2)
                    let b = U256(from: 3)
                    a *= b
                    let result = a

                    expect(result).to(equal(U256(from: 6)))
                }

                it("multiplying by one") {
                    let a = U256(from: [1, 2, 3, 4])
                    let b = U256(from: [1, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([1, 2, 3, 4]))
                    expect(isOverflow).to(beFalse())
                }

                it("multiplying max value by one") {
                    let a = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let b = U256(from: [1, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                    expect(isOverflow).to(beFalse())
                }

                it("partial overflow") {
                    let a = U256(from: [UInt64.max, 0, 0, 0])
                    let b = U256(from: [UInt64.max, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([1, UInt64.max - 1, 0, 0]))
                    expect(isOverflow).to(beFalse())
                }

                it("max without overflow") {
                    let a = U256(from: [UInt64.max, 0, 0, 0])
                    let b = U256(from: [2, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([UInt64.max - 1, 1, 0, 0]))
                    expect(isOverflow).to(beFalse())
                }

                it("overflow at index 0") {
                    let a = U256(from: [UInt64.max, 1, 0, 0])
                    let b = U256(from: [2, 0, 0, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([UInt64.max - 1, 3, 0, 0]))
                    expect(isOverflow).to(beFalse())
                }

                it("full index multiplication") {
                    let a = U256(from: [40, 30, 20, 10])
                    let b = U256(from: [3, 2, 1, 0])
                    let result = a.mul(b)

                    expect(result.BYTES).to(equal([120, 170, 160, 100]))
                }
            }

            context("with overflow") {
                it("full overflow") {
                    let a = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let b = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let (_, isOverflow) = a.overflowMul(b)

                    expect(isOverflow).to(beTrue())
                }

                it("full overflow at index 2") {
                    let a = U256(from: [0, 0, UInt64.max, 0])
                    let b = U256(from: [0, 0, 1, 0])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    expect(isOverflow).to(beTrue())
                }

                it("overflow with two max values at index 3") {
                    let a = U256(from: [0, 0, 0, UInt64.max])
                    let b = U256(from: [0, 0, 0, UInt64.max])
                    let (_, isOverflow) = a.overflowMul(b)

                    expect(isOverflow).to(beTrue())
                }

                it("overflow at index 3") {
                    let a = U256(from: [0, 0, 0, UInt64.max])
                    let b = U256(from: [0, 0, 0, 1])
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    expect(isOverflow).to(beTrue())
                }
            }

            describe("Mul operation") {
                context("without overflow") {
                    it("multiplying by zero") {
                        let a = U256(from: [1, 2, 3, 4])
                        let b = U256(from: [0, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    }

                    it("multiplying by one") {
                        let a = U256(from: [1, 2, 3, 4])
                        let b = U256(from: [1, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([1, 2, 3, 4]))
                    }

                    it("multiplying max value by one") {
                        let a = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                        let b = U256(from: [1, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                    }

                    it("partial overflow") {
                        let a = U256(from: [UInt64.max, 0, 0, 0])
                        let b = U256(from: [UInt64.max, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([1, UInt64.max - 1, 0, 0]))
                    }

                    it("max without overflow") {
                        let a = U256(from: [UInt64.max, 0, 0, 0])
                        let b = U256(from: [2, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([UInt64.max - 1, 1, 0, 0]))
                    }

                    it("overflow at index 0") {
                        let a = U256(from: [UInt64.max, 1, 0, 0])
                        let b = U256(from: [2, 0, 0, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([UInt64.max - 1, 3, 0, 0]))
                    }

                    it("full index multiplication") {
                        let a = U256(from: [40, 30, 20, 10])
                        let b = U256(from: [3, 2, 1, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([120, 170, 160, 100]))
                    }
                }

                context("with overflow") {
                    it("full overflow") {
                        let a = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                        let b = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([1, 0, 0, 0]))
                    }

                    it("full overflow at index 2") {
                        let a = U256(from: [0, 0, UInt64.max, 0])
                        let b = U256(from: [0, 0, 1, 0])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    }

                    it("overflow with two max values at index 3") {
                        let a = U256(from: [0, 0, 0, UInt64.max])
                        let b = U256(from: [0, 0, 0, UInt64.max])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    }

                    it("no overflow at index 3") {
                        let a = U256(from: [0, 0, 0, UInt64.max])
                        let b = U256(from: [0, 0, 0, 1])
                        let result = a.mul(b)

                        expect(result.BYTES).to(equal([0, 0, 0, 0]))
                    }
                }
            }
        }
    }
}
