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

    override class func spec() {
        describe("Fuzz divRem") {
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
