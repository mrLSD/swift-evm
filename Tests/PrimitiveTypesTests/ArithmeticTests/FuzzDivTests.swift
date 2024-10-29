import Nimble
import Quick

@testable import PrimitiveTypes

@available(macOS 15.0, *)
final class FuzzDivRemSpec: QuickSpec {
    override class func spec() {
        describe("Fuzz divRem") {
            func splitUInt128(_ value: UInt128) -> (high: UInt64, low: UInt64) {
                let high = UInt64(value >> 64)
                let low = UInt64(value & 0xFFFFFFFFFFFFFFFF)
                return (high, low)
            }

            it("run fuzz for divRem") {
                var index = 0
                // while index < 10 {
                index += 1

                let val1 = UInt128.random(in: 2 ... UInt128.max)
                let (hi1, lo1) = splitUInt128(val1)
                let val2 = UInt128.random(in: 2 ... UInt128.max)
                let (hi2, lo2) = splitUInt128(val2)
                let a = U128(from: [lo1, hi1])
                let b = U128(from: [lo2, hi2])
//                let (quotient, remainder) = a.divRem(divisor: b)
//
//                let div_val = val1 / val2
//                let rem_val = val1 % val2
//                let (div_hi, div_lo) = splitUInt128(div_val)
//                let (rem_hi, rem_lo) = splitUInt128(rem_val)
//                expect(quotient.BYTES).to(equal([div_lo, div_hi]))
//                expect(remainder.BYTES).to(equal([rem_lo, rem_hi]))
                // }
            }
        }
    }
}
