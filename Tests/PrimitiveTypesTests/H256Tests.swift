import Nimble
@testable import PrimitiveTypes
import Quick

final class H256Spec: QuickSpec {
    override class func spec() {
        describe("H256 type") {
            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt8]) {
                    expect(captureStandardError {
                        expect {
                            _ = H256(from: arr)
                        }.to(throwAssertion())
                    }).to(contain("must be initialized with \(H256.numberBytes) bytes array"))
                }

                context("when number of bytes") {
                    it("is Empty") {
                        expectFailInit(array: [])
                    }
                    it("is 31") {
                        expectFailInit(array: [UInt8](repeating: 0, count: 31))
                    }
                    it("is 33") {
                        expectFailInit(array: [UInt8](repeating: 0, count: 33))
                    }
                }

                context("wrong String for conversion") {
                    it("too big String") {
                        let res = H256.fromString(hex: String(repeating: "A", count: 65))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String length compared to `mod 2`") {
                        let res = H256.fromString(hex: String(repeating: "A", count: 1))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String contains wrong character G") {
                        let res = H256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0G")
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidHexCharacter("0G")))
                        })
                    }
                }
            }

            context("when init as MAX value") {
                let val = H256.MAX
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt8](repeating: UInt8.max, count: Int(H256.numberBytes))))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"))
                }
                it("correct transformed from String") {
                    let res = H256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
                    expect(res).to(beSuccess(val))
                }
            }

            context("when init as ZERO value") {
                let val = H256.ZERO
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("is Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("0000000000000000000000000000000000000000000000000000000000000000"))
                }
                it("correct transformed from String") {
                    let res = H256.fromString(hex: "0000000000000000000000000000000000000000000000000000000000000000")
                    expect(res).to(beSuccess(val))
                }
            }

            context("when init as KECCAK_EMPTY value") {
                let val = H256.KECCAK_EMPTY
                it("correct bytes") {
                    expect(val.BYTES).to(equal([
                        0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
                        0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
                        0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
                        0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70,
                    ]))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"))
                }
                it("correct transformed from String") {
                    let res = H256.fromString(hex: "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
                    expect(res).to(beSuccess(val))
                }
            }

            context("when init from H160 value (distinct bytes)") {
                // Distinct, position-varying bytes — would catch any byte-shuffle bug in the
                // H160→H256 pad logic that a uniform 0xAC pattern cannot detect.
                let h160Bytes: [UInt8] = [
                    0x01, 0x02, 0x03, 0x04,
                    0x05, 0x06, 0x07, 0x08,
                    0x09, 0x0a, 0x0b, 0x0c,
                    0x0d, 0x0e, 0x0f, 0x10,
                    0x11, 0x12, 0x13, 0x14,
                ]
                let valH160 = H160(from: h160Bytes)
                let val = H256(from: valH160)

                it("correct data: 12 leading zero bytes followed by H160 bytes in order") {
                    expect(val.BYTES).to(equal([
                        0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00,
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ]))
                }

                it("correct leading zero") {
                    expect(Array(val.BYTES[..<12]))
                        .to(equal([UInt8](repeating: 0, count: 12)))
                }
            }

            context("when converted to H160 value") {
                it("toH160() takes the last 20 bytes, dropping the upper 12") {
                    // Upper 12 bytes are non-zero and DIFFERENT from the lower 20 — confirms
                    // toH160() truly ignores the upper region and selects bytes 12..31.
                    let h256 = H256(from: [
                        0xaa, 0xaa, 0xaa, 0xaa,
                        0xbb, 0xbb, 0xbb, 0xbb,
                        0xcc, 0xcc, 0xcc, 0xcc,
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ])
                    let expected: [UInt8] = [
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ]
                    expect(h256.toH160().BYTES).to(equal(expected))
                }

                it("H160 -> H256 -> H160 round-trip preserves the address") {
                    let original = H160(from: [
                        0x01, 0x02, 0x03, 0x04,
                        0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0a, 0x0b, 0x0c,
                        0x0d, 0x0e, 0x0f, 0x10,
                        0x11, 0x12, 0x13, 0x14,
                    ])
                    let restored = H256(from: original).toH160()
                    expect(restored).to(equal(original))
                }
            }

            context("BYTES round-trip with distinct-byte input") {
                // Distinct bytes 0x01..0x20 across all 32 positions ensure any byte-shuffle
                // bug in the H256 pack/unpack pipeline is detectable.
                let bytes: [UInt8] = (1...32).map { UInt8($0) }

                it("H256(from:bytes).BYTES preserves order") {
                    let h = H256(from: bytes)
                    expect(h.BYTES).to(equal(bytes))
                }

                it("is not zero for non-zero distinct bytes") {
                    let h = H256(from: bytes)
                    expect(h.isZero).to(beFalse())
                }
            }

            context("Equality on stored fields") {
                let base: [UInt8] = (1...32).map { UInt8($0) }

                it("equal for identical bytes") {
                    // Pre-computed limbs for `base = [0x01, 0x02, ..., 0x20]`.
                    // Each limb is 8 big-endian bytes of `base`:
                    //   l0 = bytes 0..7   = 0x01..0x08
                    //   l1 = bytes 8..15  = 0x09..0x10
                    //   l2 = bytes 16..23 = 0x11..0x18
                    //   l3 = bytes 24..31 = 0x19..0x20
                    let expectedL0: UInt64 = 0x0102030405060708
                    let expectedL1: UInt64 = 0x090a0b0c0d0e0f10
                    let expectedL2: UInt64 = 0x1112131415161718
                    let expectedL3: UInt64 = 0x191a1b1c1d1e1f20

                    // 1. BYTES-init vs BYTES-init — same source path, baseline.
                    expect(H256(from: base)).to(equal(H256(from: base)))

                    // 2. BYTES-init vs UInt64-limbs-init — cross-init equivalence:
                    //    confirms that `init(from: [UInt8])` packs bytes into limbs
                    //    in the exact same order as `init(l0:l1:l2:l3:)` expects.
                    let viaLimbs = H256(l0: expectedL0, l1: expectedL1, l2: expectedL2, l3: expectedL3)
                    expect(H256(from: base)).to(equal(viaLimbs))

                    // 3. UInt64-limbs-init vs UInt64-limbs-init — same source path
                    //    on the direct field initializer.
                    let viaLimbs2 = H256(l0: expectedL0, l1: expectedL1, l2: expectedL2, l3: expectedL3)
                    expect(viaLimbs).to(equal(viaLimbs2))
                }

                it("differs at byte 0 (high half of l0)") {
                    var other = base
                    other[0] ^= 0xff
                    expect(H256(from: base)).toNot(equal(H256(from: other)))
                }

                it("differs at byte 15 (low half of l1)") {
                    var other = base
                    other[15] ^= 0xff
                    expect(H256(from: base)).toNot(equal(H256(from: other)))
                }

                it("differs at byte 23 (low half of l2)") {
                    var other = base
                    other[23] ^= 0xff
                    expect(H256(from: base)).toNot(equal(H256(from: other)))
                }

                it("differs at byte 31 (low half of l3)") {
                    var other = base
                    other[31] ^= 0xff
                    expect(H256(from: base)).toNot(equal(H256(from: other)))
                }
            }

            context("when hashing H256") {
                // Use distinct bytes — would catch byte-shuffle bugs that a uniform 0xAB pattern won't.
                let bytesA: [UInt8] = (1...32).map { UInt8($0) }
                let bytesB: [UInt8] = (1...32).map { UInt8(0x80 &+ $0) }

                it("produces the same hash for equal values") {
                    let h1 = H256(from: bytesA)
                    let h2 = H256(from: bytesA)

                    expect(h1.hashValue).to(equal(h2.hashValue))
                }

                it("can be used in a Set") {
                    let h1 = H256(from: bytesA)
                    let h2 = H256(from: bytesB)
                    let h3 = H256(from: bytesA) // same as h1

                    var set: Set<H256> = []
                    set.insert(h1)
                    set.insert(h2)
                    set.insert(h3)

                    expect(set.count).to(equal(2))
                    expect(set.contains(h1)).to(beTrue())
                    expect(set.contains(h2)).to(beTrue())
                }
            }
        }
    }
}
