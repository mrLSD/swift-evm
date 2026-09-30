import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticMulSpec: QuickSpec {
    override class func spec() {
        describe("overflowMul operation") {
            it("matches independent full products at limb boundaries and for seeded inputs") {
                var generator = SeededGenerator(state: 0xA11CE)
                func check<T: BigUInt>(_ type: T.Type, multiply: (T, T) -> T) {
                    let count = Int(T.numberBase)
                    var values = [[UInt64](repeating: 0, count: count), [UInt64](repeating: .max, count: count)]
                    for bit in 0 ..< count * 64 {
                        var value = [UInt64](repeating: 0, count: count)
                        value[bit / 64] = UInt64(1) << (bit % 64)
                        values.append(value)
                    }

                    for _ in 0 ..< 256 {
                        values.append((0 ..< count).map { _ in generator.next() })
                    }

                    for (index, a) in values.enumerated() {
                        let b = index % 2 == 0 ? [UInt64](repeating: .max, count: count) : (0 ..< count).map { _ in generator.next() }
                        let expected = fullProduct(a, b)
                        let description = "seed 0xA11CE, width \(count), a \(a), b \(b)"
                        let actual = multiply(T(from: a), T(from: b))
                        expect(actual.BYTES).to(equal(Array(expected.prefix(count))), description: description)
                        if type == U256.self {
                            let lhs = U256(from: a), rhs = U256(from: b)
                            let (low, overflow) = lhs.overflowMul(rhs)
                            expect(lhs.fullMul(rhs).BYTES).to(equal(expected), description: description)
                            expect(low.BYTES).to(equal(Array(expected.prefix(4))), description: description)
                            expect(overflow).to(equal(expected.dropFirst(4).contains { $0 != 0 }), description: description)
                        }
                    }
                }

                check(U128.self, multiply: *)
                check(U256.self, multiply: *)
                check(U512.self, multiply: *)
            }

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
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result).to(equal(U256(from: 1)))
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
                    let (result, isOverflow) = a.overflowMul(b)

                    expect(result).to(equal(U256.ZERO))
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
