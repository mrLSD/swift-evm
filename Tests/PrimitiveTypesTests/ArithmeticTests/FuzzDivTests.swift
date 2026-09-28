import Nimble
import Quick

@testable import PrimitiveTypes

final class FuzzDivRemSpec: QuickSpec {
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
            let dividends = [zero, below, divisor, above, [UInt64](repeating: .max, count: count)]
            for divisor in [below, divisor, above] where divisor != zero {
                for dividend in dividends {
                    checkDivision(type, dividend: dividend, divisor: divisor, description: "dividend \(dividend), divisor \(divisor)")
                }
            }
        }
        checkDivision(type, dividend: [UInt64](repeating: .max, count: count), divisor: [UInt64](repeating: .max, count: count), description: "MAX / MAX")
    }

    private static func checkQuotientSaturation<T: BigUInt>(_ type: T.Type) {
        let count = Int(T.numberBase)
        for words in 2 ..< count {
            for shift in 0 ..< 64 {
                var divisor = [UInt64](repeating: 0, count: count)
                divisor[0] = 1
                divisor[words - 1] = UInt64(1) << (63 - shift)
                // a = d*b-1 gives q = b-1, r = d-1, where b = 2^64.
                var dividend = [UInt64.max] + divisor.dropLast()
                dividend[1] -= 1
                var remainder = divisor
                remainder[0] -= 1
                let (q, r) = T(from: dividend).divRem(divisor: T(from: divisor))
                let description = "divisor words \(words), shift \(shift), dividend \(dividend), divisor \(divisor)"

                expect(q).to(equal(T(from: UInt64.max)), description: description)
                expect(r).to(equal(T(from: remainder)), description: description)
                expectDivisionIdentity(dividend: dividend, divisor: divisor, quotient: q.BYTES, remainder: r.BYTES, description: description)
            }
        }
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

            it("verifies U256 saturated quotient estimates for every normalization") {
                Self.checkQuotientSaturation(U256.self)
            }

            it("verifies U512 saturated quotient estimates for every normalization") {
                Self.checkQuotientSaturation(U512.self)
            }

            it("verifies word division around every divisor bit boundary") {
                var divisors: Set<UInt64> = [.max]
                for bit in 0 ..< 64 {
                    let power = UInt64(1) << bit
                    divisors.formUnion([power - 1, power, power + 1])
                }
                for divisor in divisors.sorted() where divisor != 0 {
                    for hi in Set([0, divisor / 2, divisor - 1]).sorted() {
                        for lo: UInt64 in [0, 1, .max] {
                            let (q, r) = U256.divModWord(hi: hi, lo: lo, y: divisor)
                            expectDivisionIdentity(
                                dividend: [lo, hi], divisor: [divisor, 0],
                                quotient: [q, 0], remainder: [r, 0],
                                description: "hi \(hi), lo \(lo), divisor \(divisor)"
                            )
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
