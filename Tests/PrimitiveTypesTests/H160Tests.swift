import Nimble
@testable import PrimitiveTypes
import Quick

final class H160Spec: QuickSpec {
    override class func spec() {
        describe("H160 type") {
            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt8]) {
                    expect(captureStandardError {
                        expect {
                            _ = H160(from: arr)
                        }.to(throwAssertion())
                    }).to(contain("must be initialized with \(H160.numberBytes) bytes array"))
                }

                context("when number of bytes") {
                    it("is Empty") {
                        expectFailInit(array: [])
                    }
                    it("is 19") {
                        expectFailInit(array: [UInt8](repeating: 0, count: 19))
                    }
                    it("is 21") {
                        expectFailInit(array: [UInt8](repeating: 0, count: 21))
                    }
                }

                context("wrong String for conversion") {
                    it("too big String") {
                        let res = H160.fromString(hex: String(repeating: "A", count: 41))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String length compared to `mod 2`") {
                        let res = H160.fromString(hex: String(repeating: "A", count: 1))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String contains wrong character G") {
                        let res = H160.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0G")
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidHexCharacter("0G")))
                        })
                    }
                }

                context("when init as MAX value") {
                    let val = H160.MAX
                    it("correct bytes") {
                        expect(val.BYTES).to(equal([UInt8](repeating: UInt8.max, count: Int(H160.numberBytes))))
                    }
                    it("not Zero value") {
                        expect(val.isZero).to(beFalse())
                    }
                    it("correct transformed to String") {
                        expect("\(val)").to(equal("ffffffffffffffffffffffffffffffffffffffff"))
                    }
                    it("correct transformed from String") {
                        let res = H160.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
                        expect(res).to(beSuccess(val))
                    }
                }

                context("when init as ZERO value") {
                    let val = H160.ZERO
                    it("correct bytes") {
                        expect(val.BYTES).to(equal([UInt8](repeating: 0, count: 20)))
                    }
                    it("is Zero value") {
                        expect(val.isZero).to(beTrue())
                    }
                    it("correct transformed to String") {
                        expect("\(val)").to(equal("0000000000000000000000000000000000000000"))
                    }
                    it("correct transformed from String") {
                        let res = H160.fromString(hex: "0000000000000000000000000000000000000000")
                        expect(res).to(beSuccess(val))
                    }
                }

                context("when hashing H160") {
                    // Distinct, non-repeating bytes — guards against byte-shuffle bugs that
                    // a uniform-byte input (e.g. 0xAB×20) would not detect.
                    let bytesA: [UInt8] = [
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ]
                    let bytesB: [UInt8] = [
                        0xff, 0xee, 0xdd, 0xcc,
                        0xbb, 0xaa, 0x99, 0x88,
                        0x77, 0x66, 0x55, 0x44,
                        0x33, 0x22, 0x11, 0x00,
                        0xfe, 0xed, 0xbe, 0xef,
                    ]

                    it("produces the same hash for equal values") {
                        let h1 = H160(from: bytesA)
                        let h2 = H160(from: bytesA)

                        expect(h1.hashValue).to(equal(h2.hashValue))
                    }

                    it("can be used in a Set") {
                        let h1 = H160(from: bytesA)
                        let h2 = H160(from: bytesB)
                        let h3 = H160(from: bytesA) // same as h1

                        var set: Set<H160> = []
                        set.insert(h1)
                        set.insert(h2)
                        set.insert(h3)

                        expect(set.count).to(equal(2))
                        expect(set.contains(h1)).to(beTrue())
                        expect(set.contains(h2)).to(beTrue())
                    }
                }

                context("BYTES round-trip with distinct-byte input") {
                    // Distinct bytes ensure that any byte-shuffle bug in pack/unpack is detectable.
                    let bytes: [UInt8] = [
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ]

                    it("H160(from:bytes).BYTES preserves order") {
                        let h = H160(from: bytes)
                        expect(h.BYTES).to(equal(bytes))
                    }

                    it("is not zero for non-zero distinct bytes") {
                        let h = H160(from: bytes)
                        expect(h.isZero).to(beFalse())
                    }
                }

                context("Equality on stored fields") {
                    let base: [UInt8] = [
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ]

                    it("equal for identical bytes") {
                        // Pre-computed limbs for `base = [0x01, 0x02, ..., 0x14]`:
                        //   l0 (UInt64) = bytes 0..7   = 0x01..0x08
                        //   l1 (UInt64) = bytes 8..15  = 0x09..0x10
                        //   l2 (UInt32) = bytes 16..19 = 0x11..0x14
                        let expectedL0: UInt64 = 0x0102030405060708
                        let expectedL1: UInt64 = 0x090a0b0c0d0e0f10
                        let expectedL2: UInt32 = 0x11121314

                        // 1. BYTES-init vs BYTES-init — same source path, baseline.
                        expect(H160(from: base)).to(equal(H160(from: base)))

                        // 2. BYTES-init vs UInt64/UInt32-limbs-init — cross-init equivalence:
                        //    confirms that `init(from: [UInt8])` packs bytes into limbs
                        //    in the exact same order as `init(l0:l1:l2:)` expects.
                        let viaLimbs = H160(l0: expectedL0, l1: expectedL1, l2: expectedL2)
                        expect(H160(from: base)).to(equal(viaLimbs))

                        // 3. UInt64/UInt32-limbs-init vs UInt64/UInt32-limbs-init — same source path
                        //    on the direct field initializer.
                        let viaLimbs2 = H160(l0: expectedL0, l1: expectedL1, l2: expectedL2)
                        expect(viaLimbs).to(equal(viaLimbs2))
                    }

                    it("differs at byte 0 (high half of l0)") {
                        var other = base
                        other[0] ^= 0xff
                        expect(H160(from: base)).toNot(equal(H160(from: other)))
                    }

                    it("differs at byte 7 (low half of l0)") {
                        var other = base
                        other[7] ^= 0xff
                        expect(H160(from: base)).toNot(equal(H160(from: other)))
                    }

                    it("differs at byte 15 (low half of l1)") {
                        var other = base
                        other[15] ^= 0xff
                        expect(H160(from: base)).toNot(equal(H160(from: other)))
                    }

                    it("differs at byte 19 (low byte of l2)") {
                        var other = base
                        other[19] ^= 0xff
                        expect(H160(from: base)).toNot(equal(H160(from: other)))
                    }
                }

                context("Different hex variants") {
                    it("String with 0x prefix") {
                        let hex = "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                        let res = H160.fromString(hex: hex)
                        expect(res).to(beSuccess(H160.MAX))
                    }

                    it("Empty string") {
                        let res1 = H160.fromString(hex: "0x")
                        let res2 = H160.fromString(hex: "")
                        expect(res1).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                        expect(res2).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }

                    it("Encode hex to upper case") {
                        let hex = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
                        let res = H160.MAX.encodeHexUpper()
                        let res2 = H160.MAX.encodeHexLower()
                        expect(res).to(equal(hex))
                        expect(res2.uppercased()).to(equal(res))
                    }
                }
            }
        }
    }
}
