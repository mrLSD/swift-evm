import Nimble
import Quick

@testable import PrimitiveTypes

final class FuzzDivRemSpec: QuickSpec {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    private static func bytes(_ words: [UInt64]) -> [UInt8] {
        words.flatMap { word in
            (0 ..< 8).map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) }
        }
    }

    private static func expectDivisionIdentity(dividend: [UInt64], divisor: [UInt64], quotient: [UInt64], remainder: [UInt64], description: String) {
        let a = bytes(dividend)
        let d = bytes(divisor)
        let q = bytes(quotient)
        let r = bytes(remainder)

        // Reconstruct q*d+r in base 256 with twice the input width, without library arithmetic.
        var product = [UInt32](repeating: 0, count: a.count * 2 + 1)
        for i in q.indices {
            for j in d.indices {
                product[i + j] += UInt32(q[i]) * UInt32(d[j])
            }
        }

        for i in r.indices {
            product[i] += UInt32(r[i])
        }

        for i in 0 ..< product.count - 1 {
            product[i + 1] += product[i] >> 8
            product[i] &= 0xFF
        }
        let expected = a.map(UInt32.init) + [UInt32](repeating: 0, count: product.count - a.count)

        expect(product).to(equal(expected), description: description)
        expect(r.reversed().lexicographicallyPrecedes(d.reversed())).to(beTrue(), description: description)
    }

    private static func checkDivision<T: BigUInt>(_ type: T.Type, dividend: [UInt64], divisor: [UInt64], description: String) {
        let (q, r) = T(from: dividend).divRem(divisor: T(from: divisor))
        expectDivisionIdentity(dividend: dividend, divisor: divisor, quotient: q.BYTES, remainder: r.BYTES, description: description)
    }

    private static func checkNormalizations<T: BigUInt>(_ type: T.Type, seed: UInt64) {
        var generator = SeededGenerator(state: seed)
        let count = Int(T.numberBase)
        for divisorWords in 1 ... count {
            for shift in 0 ..< 64 {
                var divisor = [UInt64](repeating: 0, count: count)
                for i in 0 ..< divisorWords {
                    divisor[i] = generator.next()
                }

                divisor[divisorWords - 1] = (generator.next() >> shift) | (UInt64(1) << (63 - shift))
                for dividendWords in divisorWords ... count {
                    var dividend = [UInt64](repeating: 0, count: count)
                    for i in 0 ..< dividendWords {
                        dividend[i] = generator.next()
                    }

                    dividend[dividendWords - 1] |= 0x8000000000000000
                    let description = "seed \(seed), shift \(shift), dividend \(dividend), divisor \(divisor)"
                    checkDivision(type, dividend: dividend, divisor: divisor, description: description)
                }
            }
        }
    }

    private static func checkLimbBoundaries<T: BigUInt>(_ type: T.Type) {
        let count = Int(T.numberBase)
        let zero = [UInt64](repeating: 0, count: count)
        for limb in 0 ..< count {
            var divisor = zero
            divisor[limb] = 1
            let below = [UInt64](repeating: .max, count: limb) + [UInt64](repeating: 0, count: count - limb)
            var above = divisor
            above[0] += 1
            for dividend in [zero, below, divisor, above, [UInt64](repeating: .max, count: count)] {
                checkDivision(type, dividend: dividend, divisor: divisor, description: "dividend \(dividend), divisor \(divisor)")
            }
        }
        checkDivision(type, dividend: [UInt64](repeating: .max, count: count), divisor: [UInt64](repeating: .max, count: count), description: "MAX / MAX")
    }

    override class func spec() {
        describe("Fuzz divRem") {
            it("verifies U256 division for every normalization and operand length") {
                Self.checkNormalizations(U256.self, seed: 0xD256)
            }

            it("verifies U512 division for every normalization and operand length") {
                Self.checkNormalizations(U512.self, seed: 0xD512)
            }

            it("verifies U256 division at every limb boundary") {
                Self.checkLimbBoundaries(U256.self)
            }

            it("verifies U512 division at every limb boundary") {
                Self.checkLimbBoundaries(U512.self)
            }

            it("verifies word division around every divisor bit boundary") {
                for bit in 0 ..< 64 {
                    let power = UInt64(1) << bit
                    let divisors = [power - 1, power, power + 1, UInt64.max].filter { $0 != 0 }
                    for divisor in divisors {
                        for hi in [0, divisor / 2, divisor - 1] {
                            for lo: UInt64 in [0, 1, .max] {
                                let (q, r) = U256.divModWord(hi: hi, lo: lo, y: divisor)
                                Self.expectDivisionIdentity(
                                    dividend: [lo, hi], divisor: [divisor, 0],
                                    quotient: [q, 0], remainder: [r, 0],
                                    description: "hi \(hi), lo \(lo), divisor \(divisor)"
                                )
                            }
                        }
                    }
                }
            }

            if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
                func splitUInt128(_ value: UInt128) -> (high: UInt64, low: UInt64) {
                    let high = UInt64(value >> 64)
                    let low = UInt64(value & 0xFFFFFFFFFFFFFFFF)
                    return (high, low)
                }

                it("run fuzz for divRem") {
                    var generator = SeededGenerator(state: 0xE7)
                    var index = 0
                    while index < 100_000 {
                        index += 1

                        let val1 = UInt128.random(in: 2 ... UInt128.max, using: &generator)
                        let (hi1, lo1) = splitUInt128(val1)
                        let val2 = UInt128.random(in: 2 ... UInt128.max, using: &generator)
                        let (hi2, lo2) = splitUInt128(val2)
                        let a = U128(from: [lo1, hi1])
                        let b = U128(from: [lo2, hi2])
                        let (quotient, remainder) = a.divRem(divisor: b)

                        let div_val = val1 / val2

                        let rem_val = val1 % val2
                        let (div_hi, div_lo) = splitUInt128(div_val)
                        let (rem_hi, rem_lo) = splitUInt128(rem_val)
                        let description = "seed 0xE7, iteration \(index), dividend \(val1), divisor \(val2)"
                        expect(quotient.BYTES).to(equal([div_lo, div_hi]), description: description)
                        expect(remainder.BYTES).to(equal([rem_lo, rem_hi]), description: description)
                    }
                }

                it("matches UInt128 for full-width word division") {
                    var generator = SeededGenerator(state: 0xD164)
                    for index in 0 ..< 20_000 {
                        let divisor = UInt64.random(in: 1 ... .max, using: &generator)
                        let hi = UInt64.random(in: 0 ..< divisor, using: &generator)
                        let lo = generator.next()
                        let dividend = (UInt128(hi) << 64) | UInt128(lo)
                        let (q, r) = U256.divModWord(hi: hi, lo: lo, y: divisor)
                        let description = "seed 0xD164, iteration \(index), hi \(hi), lo \(lo), divisor \(divisor)"

                        expect(q).to(equal(UInt64(dividend / UInt128(divisor))), description: description)
                        expect(r).to(equal(UInt64(dividend % UInt128(divisor))), description: description)
                        expect(r < divisor).to(beTrue(), description: description)
                    }
                }
            }
        }
    }
}
