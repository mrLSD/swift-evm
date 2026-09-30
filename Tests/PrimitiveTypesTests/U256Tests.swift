import Nimble
@testable import PrimitiveTypes
import Quick

final class U256Spec: QuickSpec {
    override class func spec() {
        describe("U256 type") {
            context("word conversions") {
                it("reads every big-endian length at unaligned offsets and preserves surrounding bytes") {
                    let bytes = (0 ..< 32).map { UInt8($0 * 7 + 1) }
                    for offset in 0 ... 7 {
                        for length in 0 ... 32 {
                            let storage = [UInt8](repeating: 0xFF, count: offset) + bytes + [0xFF]
                            let actual = storage.withUnsafeBytes {
                                U256(bigEndian: UnsafeRawBufferPointer(rebasing: $0[offset ..< offset + length]))
                            }
                            var expected = [UInt64](repeating: 0, count: 4)
                            for i in 0 ..< length {
                                expected[i / 8] |= UInt64(bytes[length - 1 - i]) << ((i % 8) * 8)
                            }
                            expect(actual.BYTES).to(equal(expected), description: "offset \(offset), length \(length)")
                        }
                        var storage = [UInt8](repeating: 0xEE, count: offset + 33)
                        let value = U256(from: [0x0123456789ABCDEF, 0x1020304050607080, 0xFFEEDDCCBBAA9988, 0x8877665544332211])
                        storage.withUnsafeMutableBytes {
                            value.writeBigEndian(to: UnsafeMutableRawBufferPointer(rebasing: $0[offset ..< offset + 32]))
                        }
                        let expected: [UInt8] = [0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88,
                                                 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
                        expect(storage).to(equal([UInt8](repeating: 0xEE, count: offset) + expected + [0xEE]))
                    }
                }

                it("rejects oversized reads and incorrectly sized write buffers") {
                    expect(captureStandardError {
                        expect {
                            [UInt8](repeating: 0, count: 33).withUnsafeBytes { _ = U256(bigEndian: $0) }
                        }.to(throwAssertion())
                    }).to(contain("not more than 32 bytes"))
                    for count in [0, 31, 33] {
                        expect(captureStandardError {
                            expect {
                                var bytes = [UInt8](repeating: 0, count: count)
                                bytes.withUnsafeMutableBytes { U256.ZERO.writeBigEndian(to: $0) }
                            }.to(throwAssertion())
                        }).to(contain("32-byte destination"))
                    }
                }

                it("truncates only high limbs and converts hash words in big-endian order") {
                    let wide = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(U256(truncating: wide).BYTES).to(equal([1, 2, 3, 4]))
                    expect(U256(truncating: .MAX)).to(equal(.MAX))
                    let hash = H256(from: Array(0 ..< 32))
                    let word = U256(from: hash)
                    expect(word.BYTES).to(equal([0x18191A1B1C1D1E1F, 0x1011121314151617, 0x08090A0B0C0D0E0F, 0x0001020304050607]))
                    expect(H256(from: word)).to(equal(hash))
                }
            }

            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt64]) {
                    expect(captureStandardError {
                        expect {
                            _ = U256(from: arr)
                        }.to(throwAssertion())
                    }).to(contain("must be initialized with 4 UInt64 values"))
                }

                context("when number of bytes") {
                    it("is Empty") {
                        expectFailInit(array: [])
                    }
                    it("is 1") {
                        expectFailInit(array: [0])
                    }
                    it("is 5") {
                        expectFailInit(array: [0, 0, 0, 0, 0])
                    }
                    it("from Little Endian 33 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = U256.fromLittleEndian(from: [UInt8](repeating: 0, count: 33))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 32 bytes"))
                    }
                    it("from Big Endian 33 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = U256.fromBigEndian(from: [UInt8](repeating: 0, count: 33))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 32 bytes"))
                    }
                }

                context("String validation") {
                    it("rejects signs, whitespace and non-ASCII hex digits") {
                        let cases: [(hex: String, invalid: String)] = [
                            ("+1", "+1"), ("-1", "-1"), ("-0", "-0"), ("00+a", "+a"), ("0x+1", "+1"), ("0X+F", "+F"),
                            (" 1", " 1"), ("1 ", "1 "), ("\t1", "\t1"), ("1\n", "1\n"), ("Ａ1", "Ａ1"), ("é0", "é0")
                        ]
                        for (hex, invalid) in cases {
                            expect(U256.fromString(hex: hex)).to(beFailure { error in
                                expect(error).to(equal(.InvalidHexCharacter(invalid)))
                            }, description: "hex \(hex)")
                        }
                    }

                    it("preserves empty, prefixed, odd-length and mixed-case hex") {
                        for hex in ["", "0x", "0X", "0", "00"] {
                            expect(U256.fromString(hex: hex)).to(beSuccess(U256.ZERO), description: "hex \(hex)")
                        }

                        for hex in ["aBc", "0xaBc", "0XaBc", "0AbC"] {
                            expect(U256.fromString(hex: hex)).to(beSuccess(U256(from: 0xABC)), description: "hex \(hex)")
                        }
                    }

                    it("too big String") {
                        let res = U256.fromString(hex: String(repeating: "A", count: 65))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String length compared to `mod 2`") {
                        let res = U256.fromString(hex: String(repeating: "A", count: 1))
                        expect(res).to(beSuccess(U256(from: 0xA)))
                    }
                    it("String contains wrong character G") {
                        let res = U256.fromString(hex: "0G")
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidHexCharacter("0G")))
                        })
                    }
                }
            }

            context("when convert from small numbers") {
                it("correct transformed from Little Endian number 0x01AC") {
                    expect(U256.fromLittleEndian(from: [0x1, 0xAC])).to(equal(U256(from: [0xAC01, 0, 0, 0])))
                }
                it("correct transformed from Big Endian number 0x01AC") {
                    expect(U256.fromBigEndian(from: [0x1, 0xAC])).to(equal(U256(from: [0x01AC, 0, 0, 0])))
                }
            }

            context("when init as MAX value") {
                let val = U256.MAX
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(U256(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"))
                }
                it("correct transformed from String") {
                    let res = U256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
                    expect(res).to(beSuccess(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0xFF, count: 32)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0xFF, count: 32)))
                }
                it("correct transformed from Little Endian") {
                    expect(U256.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(U256.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when init as ZERO value") {
                let val = U256.ZERO
                it("correct bytes") {
                    expect(val.BYTES).to(equal([0, 0, 0, 0]))
                }
                it("is Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(U256(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("0"))
                }
                it("correct transformed from String") {
                    let res = U256.fromString(hex: "0000000000000000000000000000000000000000000000000000000000000000")
                    expect(res).to(beSuccess(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("correct transformed from Little Endian") {
                    expect(U256.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(U256.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when concrete U256 value") {
                it("from Big-Endian") {
                    let val = U256.fromBigEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x000000000000AC02).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x0F010203C1000000).to(equal(val.BYTES[3]))
                }
                it("from Little-Endian") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x000000C10302010F).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x02AC000000000000).to(equal(val.BYTES[3]))
                }

                it("getUInt") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getUInt).to(beNil())

                    let val2 = U256(from: [0xFFFF, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getUInt))
                }

                it("getInt") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getInt).to(beNil())

                    let val2 = U256(from: [0xFFFF, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getInt))
                }

                it("saturatingInt") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.saturatingInt).to(equal(Int.max))

                    let val2 = U256(from: [0xFFFF, 0, 0, 0])
                    expect(val2.saturatingInt).to(equal(0xFFFF))
                }
            }

            context("when compare numbers") {
                it("==") {
                    let val1 = U256(from: [1, 2, 3, 4])
                    let val2 = U256(from: [1, 2, 3, 4])
                    expect(val1 == val2).to(beTrue())
                }

                it("!=") {
                    let val1 = U256(from: [1, 2, 3, 4])
                    let val2 = U256(from: [1, 2, 3, 5])
                    expect(val1 != val2).to(beTrue())

                    let val3 = U256(from: [1, 2, 3, 4])
                    let val4 = U256(from: [1, 2, 3, 4])
                    expect(val3 != val4).to(beFalse())
                }

                it("<") {
                    let val1 = U256(from: [1, 2, 3, 4])
                    let val2 = U256(from: [1, 2, 3, 5])
                    expect(val1 < val2).to(beTrue())

                    let val3 = U256(from: [1, 2, 3, 5])
                    let val4 = U256(from: [1, 2, 3, 4])
                    expect(val3 < val4).to(beFalse())

                    let val5 = U256(from: [1, 2, 3, 4])
                    let val6 = U256(from: [1, 2, 3, 4])
                    expect(val5 < val6).to(beFalse())
                }

                it(">") {
                    let val1 = U256(from: [1, 2, 3, 5])
                    let val2 = U256(from: [1, 2, 3, 4])
                    expect(val1 > val2).to(beTrue())

                    let val3 = U256(from: [1, 2, 3, 4])
                    let val4 = U256(from: [1, 2, 3, 5])
                    expect(val3 > val4).to(beFalse())

                    let val5 = U256(from: [1, 2, 3, 4])
                    let val6 = U256(from: [1, 2, 3, 4])
                    expect(val5 > val6).to(beFalse())
                }

                it("<, > combinations") {
                    let lower = U256(from: [0, 0, 0, 1])
                    let higher = U256(from: [0, 0, 0, 2])
                    let equal = U256(from: [0, 0, 0, 1])

                    expect(lower < higher).to(beTrue())
                    expect(higher > lower).to(beTrue())
                    expect(lower < equal).to(beFalse())
                    expect(equal > higher).to(beFalse())
                }

                it("edge cases") {
                    let zero = U256.ZERO
                    let max = U256.MAX
                    let one = U256(from: UInt64(1))
                    let nearMax = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max - 1])

                    // Zero comparisons
                    expect(zero < one).to(beTrue())
                    expect(one > zero).to(beTrue())
                    expect(zero < max).to(beTrue())
                    expect(max > zero).to(beTrue())

                    // Near max comparisons
                    expect(nearMax < max).to(beTrue())
                    expect(max > nearMax).to(beTrue())
                    expect(nearMax > one).to(beTrue())
                    expect(one < nearMax).to(beTrue())

                    // Equal to MAX
                    let anotherMax = U256.MAX
                    expect(max == anotherMax).to(beTrue())
                    expect(max > anotherMax).to(beFalse())
                    expect(max < anotherMax).to(beFalse())
                }

                it("<=") {
                    let val1 = U256(from: [1, 2, 3, 4])
                    let val2 = U256(from: [1, 2, 3, 5])
                    let val3 = U256(from: [1, 2, 3, 4])
                    let val4 = U256(from: [0, 0, 0, 0])
                    let val5 = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])

                    // Basic comparisons
                    expect(val1 <= val2).to(beTrue())
                    expect(val2 <= val1).to(beFalse())
                    expect(val1 <= val3).to(beTrue())

                    // Comparing with ZERO
                    expect(val4 <= val1).to(beTrue())
                    expect(val4 <= val4).to(beTrue())

                    // Comparing with MAX
                    expect(val5 <= val5).to(beTrue())
                    expect(val1 <= val5).to(beTrue())
                    expect(val5 <= val1).to(beFalse())
                }

                it(">=") {
                    let val1 = U256(from: [1, 2, 3, 5])
                    let val2 = U256(from: [1, 2, 3, 4])
                    let val3 = U256(from: [1, 2, 3, 5])
                    let val4 = U256(from: [0, 0, 0, 0])
                    let val5 = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])

                    // Basic comparisons
                    expect(val1 >= val2).to(beTrue())
                    expect(val2 >= val1).to(beFalse())
                    expect(val1 >= val3).to(beTrue())

                    // Comparing with ZERO
                    expect(val1 >= val4).to(beTrue())
                    expect(val4 >= val4).to(beTrue())

                    // Comparing with MAX
                    expect(val5 >= val5).to(beTrue())
                    expect(val5 >= val1).to(beTrue())
                    expect(val1 >= val5).to(beFalse())
                }
            }
        }
    }
}
