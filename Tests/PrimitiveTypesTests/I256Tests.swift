import Nimble
@testable import PrimitiveTypes
import Quick

final class I256Spec: QuickSpec {
    private static func checkDivisionSigns(dividend: [UInt64], divisor: [UInt64], description: String) {
        let minimum: [UInt64] = [0, 0, 0, 0x8000_0000_0000_0000]
        for negativeDividend in [false, true] where dividend != minimum || negativeDividend {
            for negativeDivisor in [false, true] where divisor != minimum || negativeDivisor {
                let a = I256(from: dividend, signExtend: negativeDividend)
                let d = I256(from: divisor, signExtend: negativeDivisor)
                let q = a / d
                let r = a % d
                let description = "\(description), dividend \(dividend), divisor \(divisor), signs \(negativeDividend), \(negativeDivisor)"
                let quotientIsZero = q.BYTES.allSatisfy { $0 == 0 }
                let remainderIsZero = r.BYTES.allSatisfy { $0 == 0 }
                // EVM keeps MIN / -1 negative; the magnitude identity still holds.
                let minimumQuotient = dividend == minimum && divisor == [1, 0, 0, 0]

                expectDivisionIdentity(dividend: dividend, divisor: divisor, quotient: q.BYTES, remainder: r.BYTES, description: description)
                expect(q.signExtend).to(equal(!quotientIsZero && (minimumQuotient || negativeDividend != negativeDivisor)), description: description)
                expect(r.signExtend).to(equal(!remainderIsZero && negativeDividend), description: description)
            }
        }
    }

    private static func randomMagnitude(words: Int, generator: inout SeededGenerator) -> [UInt64] {
        var magnitude = [UInt64](repeating: 0, count: 4)
        for i in 0 ..< words {
            magnitude[i] = generator.next()
        }
        magnitude[3] &= 0x7FFF_FFFF_FFFF_FFFF
        magnitude[words - 1] = max(1, magnitude[words - 1])
        return magnitude
    }

    override class func spec() {
        describe("I256 type") {
            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt64]) {
                    expect(captureStandardError {
                        expect {
                            _ = I256(from: arr)
                        }.to(throwAssertion())
                    }).to(contain("must be initialized with 4 UInt64 values"))
                }

                context("when number of bytes") {
                    it("is Empty with sign extend") {
                        expect(captureStandardError {
                            expect {
                                _ = I256(from: [], signExtend: true)
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with 4 UInt64 values"))
                    }
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
                                _ = I256.fromLittleEndian(from: [UInt8](repeating: 0, count: 33))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 32 bytes"))
                    }
                    it("from Big Endian 33 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = I256.fromBigEndian(from: [UInt8](repeating: 0, count: 33))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 32 bytes"))
                    }
                }

                context("wrong String for conversion") {
                    it("too big String") {
                        let res = I256.fromString(hex: String(repeating: "A", count: 65))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String length compared to `mod 2`") {
                        let res = I256.fromString(hex: String(repeating: "A", count: 1))
                        expect(res).to(beSuccess(I256(from: 0xA)))
                    }
                    it("String contains wrong character G") {
                        let res = I256.fromString(hex: "0G")
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidHexCharacter("0G")))
                        })
                    }
                }
            }

            context("when convert from small numbers") {
                it("correct transformed from Little Endian number 0x01AC") {
                    expect(I256.fromLittleEndian(from: [0x1, 0xAC])).to(equal(I256(from: [0xAC01, 0, 0, 0])))
                }
                it("correct transformed from Big Endian number 0x01AC") {
                    expect(I256.fromBigEndian(from: [0x1, 0xAC])).to(equal(I256(from: [0x01AC, 0, 0, 0])))
                }
            }

            context("when init as MAX value") {
                let val = I256.MAX
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(I256(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"))
                }
                it("correct transformed from String") {
                    let res = I256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
                    expect(res).to(beSuccess(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0xFF, count: 32)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0xFF, count: 32)))
                }
                it("correct transformed from Little Endian") {
                    expect(I256.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(I256.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when init as ZERO value") {
                let val = I256.ZERO
                it("correct bytes") {
                    expect(val.BYTES).to(equal([0, 0, 0, 0]))
                }
                it("is Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(I256(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("0"))
                }
                it("correct transformed from String") {
                    let res = I256.fromString(hex: "0000000000000000000000000000000000000000000000000000000000000000")
                    expect(res).to(beSuccess(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("correct transformed from Little Endian") {
                    expect(I256.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(I256.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
                it("normalizes zero with sign extension") {
                    let fieldZero = I256(l0: 0, l1: 0, h0: 0, h1: 0, signExtend: true)
                    let arrayZero = I256(from: [0, 0, 0, 0], signExtend: true)

                    expect(fieldZero).to(equal(I256.ZERO))
                    expect(arrayZero).to(equal(I256.ZERO))
                    expect(fieldZero.signExtend).to(beFalse())
                    expect(arrayZero.signExtend).to(beFalse())
                }
            }

            context("when concrete I256 value") {
                it("from Big-Endian") {
                    let val = I256.fromBigEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x0000_0000_0000_AC02).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x0F01_0203_C100_0000).to(equal(val.BYTES[3]))
                }
                it("from Little-Endian") {
                    let val = I256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x0000_00C1_0302_010F).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x02AC_0000_0000_0000).to(equal(val.BYTES[3]))
                }

                it("getUInt") {
                    let val = I256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getUInt).to(beNil())

                    let val2 = I256(from: [0xFFFF, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getUInt))
                }

                it("getInt") {
                    let val = I256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getInt).to(beNil())

                    let val2 = I256(from: [0xFFFF, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getInt))
                }

                it("saturatingInt") {
                    let val = I256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.saturatingInt).to(equal(Int.max))

                    let val2 = I256(from: [0xFFFF, 0, 0, 0])
                    expect(val2.saturatingInt).to(equal(0xFFFF))
                }
            }

            context("when compare numbers") {
                it("==") {
                    let val1 = I256(from: [1, 2, 3, 4])
                    let val2 = I256(from: [1, 2, 3, 4])
                    expect(val1 == val2).to(beTrue())
                }

                it("== [sign extend, not sign extend]") {
                    let val1 = I256(from: [5, 0, 0, 0], signExtend: true)
                    let val2 = I256(from: [5, 0, 0, 0])
                    expect(val1 == val2).to(beFalse())
                }

                it("== [not sign extend, sign extend]") {
                    let val1 = I256(from: [5, 0, 0, 0])
                    let val2 = I256(from: [5, 0, 0, 0], signExtend: true)
                    expect(val1 == val2).to(beFalse())
                }

                it("== [sign extend, sign extend]") {
                    let val1 = I256(from: [5, 0, 0, 0], signExtend: true)
                    let val2 = I256(from: [5, 0, 0, 0], signExtend: true)
                    expect(val1 == val2).to(beTrue())
                }

                it("!=") {
                    let val1 = I256(from: [1, 2, 3, 4])
                    let val2 = I256(from: [1, 2, 3, 5])
                    expect(val1 != val2).to(beTrue())

                    let val3 = I256(from: [1, 2, 3, 4])
                    let val4 = I256(from: [1, 2, 3, 4])
                    expect(val3 != val4).to(beFalse())

                    let val5 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val6 = I256(from: [3, 0, 0, 0])
                    expect(val5 != val6).to(beTrue())

                    let val7 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val8 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val7 != val8).to(beFalse())
                }

                it("!= [sign extend, sign extend]") {
                    let val1 = I256(from: [5, 0, 0, 0], signExtend: true)
                    let val2 = I256(from: [6, 0, 0, 0], signExtend: true)
                    expect(val1 != val2).to(beTrue())
                }

                it("<") {
                    let val1 = I256(from: [1, 2, 3, 4])
                    let val2 = I256(from: [1, 2, 3, 5])
                    expect(val1 < val2).to(beTrue())

                    let val3 = I256(from: [1, 2, 3, 5])
                    let val4 = I256(from: [1, 2, 3, 4])
                    expect(val3 < val4).to(beFalse())

                    let val5 = I256(from: [1, 2, 3, 4])
                    let val6 = I256(from: [1, 2, 3, 4])
                    expect(val5 < val6).to(beFalse())

                    let val7 = I256(from: [2, 0, 0, 0])
                    let val8 = I256(from: [3, 0, 0, 0])
                    expect(val7 < val8).to(beTrue())

                    let val9 = I256(from: [2, 0, 0, 0])
                    let val10 = I256(from: [2, 0, 0, 0])
                    expect(val9 < val10).to(beFalse())

                    let val11 = I256(from: [2, 0, 0, 0])
                    let val12 = I256(from: [1, 0, 0, 0])
                    expect(val11 < val12).to(beFalse())

                    // Differs only at h0 limb
                    let val13 = I256(from: [9, 9, 1, 9])
                    let val14 = I256(from: [9, 9, 2, 9])
                    expect(val13 < val14).to(beTrue())

                    // Differs only at l1 limb
                    let val15 = I256(from: [9, 1, 9, 9])
                    let val16 = I256(from: [9, 2, 9, 9])
                    expect(val15 < val16).to(beTrue())
                }

                it("< [sign extend, not sign extend]") {
                    let val1 = I256(from: [1, 2, 3, 4], signExtend: true)
                    let val2 = I256(from: [1, 2, 3, 5], signExtend: false)
                    expect(val1 < val2).to(beTrue())

                    let val3 = I256(from: [1, 2, 3, 5], signExtend: true)
                    let val4 = I256(from: [1, 2, 3, 4], signExtend: false)
                    expect(val3 < val4).to(beTrue())

                    let val5 = I256(from: [1, 2, 3, 4], signExtend: true)
                    let val6 = I256(from: [1, 2, 3, 4], signExtend: false)
                    expect(val5 < val6).to(beTrue())
                    expect(val5 == val6).to(beFalse())

                    let val7 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val8 = I256(from: [2, 0, 0, 0], signExtend: false)
                    expect(val7 < val8).to(beTrue())

                    let val9 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val10 = I256(from: [3, 0, 0, 0], signExtend: false)
                    expect(val9 < val10).to(beTrue())

                    let val11 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val12 = I256(from: [5, 0, 0, 0], signExtend: false)
                    expect(val11 < val12).to(beTrue())
                }

                it("< [not sign extend, sign extend]") {
                    let val1 = I256(from: [1, 2, 3, 4], signExtend: false)
                    let val2 = I256(from: [1, 2, 3, 5], signExtend: true)
                    expect(val1 < val2).to(beFalse())

                    let val3 = I256(from: [1, 2, 3, 5], signExtend: false)
                    let val4 = I256(from: [1, 2, 3, 4], signExtend: true)
                    expect(val3 < val4).to(beFalse())

                    let val5 = I256(from: [1, 2, 3, 4], signExtend: false)
                    let val6 = I256(from: [1, 2, 3, 4], signExtend: true)
                    expect(val5 < val6).to(beFalse())
                    expect(val5 == val6).to(beFalse())

                    let val7 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val8 = I256(from: [2, 0, 0, 0], signExtend: true)
                    expect(val7 < val8).to(beFalse())

                    let val9 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val10 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val9 < val10).to(beFalse())

                    let val11 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val12 = I256(from: [5, 0, 0, 0], signExtend: true)
                    expect(val11 < val12).to(beFalse())
                }

                it("< [sign extend, sign extend]") {
                    let val1 = I256(from: [1, 2, 3, 4], signExtend: true)
                    let val2 = I256(from: [1, 2, 3, 3], signExtend: true)
                    expect(val1 < val2).to(beTrue())

                    let val3 = I256(from: [1, 2, 3, 3], signExtend: true)
                    let val4 = I256(from: [1, 2, 3, 4], signExtend: true)
                    expect(val3 < val4).to(beFalse())

                    let val5 = I256(from: [1, 2, 3, 4], signExtend: true)
                    let val6 = I256(from: [1, 2, 3, 4], signExtend: true)
                    expect(val5 < val6).to(beFalse())

                    let val7 = I256(from: [1, 2, 3, 5], signExtend: true)
                    let val8 = I256(from: [1, 2, 3, 5], signExtend: true)
                    expect(val7 == val8).to(beTrue())

                    let val9 = I256(from: [4, 0, 0, 0], signExtend: true)
                    let val10 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val9 < val10).to(beTrue())

                    let val11 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val12 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val11 < val12).to(beFalse())

                    let val13 = I256(from: [2, 0, 0, 0], signExtend: true)
                    let val14 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val13 < val14).to(beFalse())
                }

                it(">") {
                    let val1 = I256(from: [1, 2, 3, 5])
                    let val2 = I256(from: [1, 2, 3, 4])
                    expect(val1 > val2).to(beTrue())

                    let val3 = I256(from: [1, 2, 3, 4])
                    let val4 = I256(from: [1, 2, 3, 5])
                    expect(val3 > val4).to(beFalse())

                    let val5 = I256(from: [1, 2, 3, 4])
                    let val6 = I256(from: [1, 2, 3, 4])
                    expect(val5 > val6).to(beFalse())

                    let val7 = I256(from: [3, 0, 0, 0])
                    let val8 = I256(from: [2, 0, 0, 0])
                    expect(val7 > val8).to(beTrue())

                    let val9 = I256(from: [2, 0, 0, 0])
                    let val10 = I256(from: [2, 0, 0, 0])
                    expect(val9 > val10).to(beFalse())

                    let val11 = I256(from: [2, 0, 0, 0])
                    let val12 = I256(from: [3, 0, 0, 0])
                    expect(val11 > val12).to(beFalse())
                }

                it("> [sign extend, not sign extend]") {
                    let val1 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val2 = I256(from: [2, 0, 0, 0], signExtend: false)
                    expect(val1 > val2).to(beFalse())

                    let val3 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val4 = I256(from: [3, 0, 0, 0], signExtend: false)
                    expect(val3 > val4).to(beFalse())

                    let val5 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val6 = I256(from: [5, 0, 0, 0], signExtend: false)
                    expect(val5 > val6).to(beFalse())
                }

                it("> [not sign extend, sign extend]") {
                    let val1 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val2 = I256(from: [2, 0, 0, 0], signExtend: true)
                    expect(val1 > val2).to(beTrue())

                    let val3 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val4 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val3 > val4).to(beTrue())

                    let val5 = I256(from: [3, 0, 0, 0], signExtend: false)
                    let val6 = I256(from: [5, 0, 0, 0], signExtend: true)
                    expect(val5 > val6).to(beTrue())
                }

                it("> [sign extend, sign extend]") {
                    let val1 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val2 = I256(from: [2, 0, 0, 0], signExtend: true)
                    expect(val1 > val2).to(beFalse())

                    let val3 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val4 = I256(from: [3, 0, 0, 0], signExtend: true)
                    expect(val3 > val4).to(beFalse())

                    let val5 = I256(from: [3, 0, 0, 0], signExtend: true)
                    let val6 = I256(from: [5, 0, 0, 0], signExtend: true)
                    expect(val5 > val6).to(beTrue())
                }

                it("<, > combinations") {
                    let lower = I256(from: [0, 0, 0, 1])
                    let higher = I256(from: [0, 0, 0, 2])
                    let equal = I256(from: [0, 0, 0, 1])

                    expect(lower < higher).to(beTrue())
                    expect(higher > lower).to(beTrue())
                    expect(lower < equal).to(beFalse())
                    expect(equal > higher).to(beFalse())
                }

                it("edge cases") {
                    let zero = I256.ZERO
                    let max = I256.MAX
                    let one = I256(from: UInt64(1))
                    let nearMax = I256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max - 1])

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
                    let anotherMax = I256.MAX
                    expect(max == anotherMax).to(beTrue())
                    expect(max > anotherMax).to(beFalse())
                    expect(max < anotherMax).to(beFalse())
                }

                it("<=") {
                    let val1 = I256(from: [1, 2, 3, 4])
                    let val2 = I256(from: [1, 2, 3, 5])
                    let val3 = I256(from: [1, 2, 3, 4])
                    let val4 = I256(from: [0, 0, 0, 0])
                    let val5 = I256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let val6 = I256(from: [5, 0, 0, 0], signExtend: true)
                    let val7 = I256(from: [6, 0, 0, 0], signExtend: true)

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

                    expect(val6 <= val4).to(beTrue())
                    expect(val7 <= val6).to(beTrue())
                    expect(val6 <= val7).to(beFalse())
                    expect(val6 <= val6).to(beTrue())
                }

                it(">=") {
                    let val1 = I256(from: [1, 2, 3, 5])
                    let val2 = I256(from: [1, 2, 3, 4])
                    let val3 = I256(from: [1, 2, 3, 5])
                    let val4 = I256(from: [0, 0, 0, 0])
                    let val5 = I256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let val6 = I256(from: [5, 0, 0, 0], signExtend: true)
                    let val7 = I256(from: [6, 0, 0, 0], signExtend: true)

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

                    expect(val6 >= val4).to(beFalse())
                    expect(val7 >= val6).to(beFalse())
                    expect(val6 >= val7).to(beTrue())
                    expect(val6 >= val6).to(beTrue())
                }
            }

            context("from and to U256") {
                it("fromU256 with positive U256 value") {
                    let u256Value = U256(from: [1, 2, 3, 4])
                    let result = I256.fromU256(u256Value)
                    let expected = I256(from: [1, 2, 3, 4], signExtend: false)

                    expect(result).to(equal(expected))
                }

                it("fromU256 with negative U256 value (signExtend true)") {
                    let u256Value = U256(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max])
                    let result = I256.fromU256(u256Value)
                    let expected = I256(from: [1, 0, 0, 0], signExtend: true)

                    expect(result).to(equal(expected))
                }

                it("toU256 with positive I256 value (signExtend false)") {
                    let i256Value = I256(from: [1, 2, 3, 4], signExtend: false)
                    let result = i256Value.toU256
                    let expected = U256(from: [1, 2, 3, 4])

                    expect(result).to(equal(expected))
                }

                it("toU256 with negative I256 value (signExtend true)") {
                    let i256Value = I256(from: [UInt64.max, UInt64.max, 0, 0], signExtend: true)
                    let result = i256Value.toU256
                    let expected = U256(from: [1, 0, UInt64.max, UInt64.max])

                    expect(result).to(equal(expected))
                }
            }

            context("shift arithmetic right (SAR)") {
                func referenceShift(_ value: U256, by shift: Int) -> U256 {
                    if shift <= 0 {
                        return value
                    }

                    let signBit = U256(l0: 0, l1: 0, h0: 0, h1: 0x8000_0000_0000_0000)
                    let isNegative = !(value & signBit).isZero
                    if shift >= 256 {
                        return isNegative ? U256.MAX : U256.ZERO
                    }

                    var result = value
                    for _ in 0 ..< shift {
                        result = result >> 1
                        if isNegative {
                            result = result | signBit
                        }
                    }
                    return result
                }

                it("shiftRight with positive I256 value, no sign extension") {
                    let i256Value = I256(from: [0, 0, 0, 1], signExtend: false)
                    let result = i256Value >> 1
                    let expected = U256(from: [0, 0, 0, 1]) >> 1

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("shiftRight with positive I256 value, zero shift") {
                    let i256Value = I256(from: [0, 0, 0, 1], signExtend: false)
                    let result = i256Value >> 0
                    let expected = U256(from: [0, 0, 0, 1]) >> 0

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("shiftRight with negative I256 value, with sign extension") {
                    let i256Value = U256(from: [0, UInt64.max - 2, UInt64.max - 2, UInt64.max])
                    let result = I256.fromU256(i256Value) >> 3
                    let expected = U256(from: [0xA000_0000_0000_0000, 0xBFFF_FFFF_FFFF_FFFF, UInt64.max, UInt64.max])

                    expect(result.toU256).to(equal(expected))
                }

                it("shiftRight with negative I256 value, with sign extension") {
                    let i256Value = U256(from: [UInt64.max / 3, UInt64.max / 2, UInt64.max / 2, UInt64.max - 0xFF])
                    let result = I256.fromU256(i256Value) >> 4
                    let expected = U256(from: [0xF555_5555_5555_5555, 0xF7FF_FFFF_FFFF_FFFF, 0x7FFFFFFFFFFFFFF, 0xFFFF_FFFF_FFFF_FFF0])

                    expect(result.toU256).to(equal(expected))
                }

                it("shiftRight with positive I256 value -1, with shift 257") {
                    let i256Value = I256(from: [1, 0, 0, 0], signExtend: true)
                    let result = i256Value >> 257
                    let expected = U256.MAX

                    expect(result.toU256).to(equal(expected))
                }

                it("shiftRight with positive I256 value 0") {
                    let i256Value = I256.ZERO
                    let result = i256Value >> 1
                    let expected = U256.ZERO

                    expect(result.toU256).to(equal(expected))
                }

                it("matches signed values and shift boundaries") {
                    let values: [(String, U256)] = [
                        ("zero", .ZERO),
                        ("one", U256(from: 1)),
                        ("signed max", I256.SIGN_BIT_MASK),
                        ("mixed positive", U256(l0: .max, l1: 2, h0: 3, h1: 4)),
                        ("signed min", I256.minValue.toU256),
                        ("minus one", .MAX),
                        ("minus three", U256.MAX - U256(from: 2)),
                        ("mixed negative", U256(l0: 1, l1: 2, h0: 3, h1: 0x8000_0000_0000_0004)),
                    ]
                    let shifts = [-1, 0, 1, 2, 63, 64, 65, 127, 128, 129, 191, 192, 193, 254, 255, 256, 257]

                    for (name, value) in values {
                        for shift in shifts {
                            let result = (I256.fromU256(value) >> shift).toU256
                            expect(result).to(
                                equal(referenceShift(value, by: shift)),
                                description: "\(name) >> \(shift)"
                            )
                        }
                    }
                }
            }

            context("div operation") {
                it("preserves the magnitude identity and signs at signed and limb boundaries") {
                    var magnitudes: [[UInt64]] = [
                        [0, 0, 0, 0], [1, 0, 0, 0], [2, 0, 0, 0],
                        [.max, .max, .max, 0x7FFF_FFFF_FFFF_FFFF], [0, 0, 0, 0x8000_0000_0000_0000],
                    ]
                    for limb in 1 ..< 4 {
                        var power: [UInt64] = [0, 0, 0, 0]
                        power[limb] = 1
                        let below = [UInt64](repeating: .max, count: limb) + [UInt64](repeating: 0, count: 4 - limb)
                        var above = power
                        above[0] = 1
                        magnitudes += [below, power, above]
                    }

                    for dividend in magnitudes {
                        for divisor in magnitudes.dropFirst() {
                            Self.checkDivisionSigns(dividend: dividend, divisor: divisor, description: "signed boundary")
                        }
                    }
                }

                it("preserves the magnitude identity and signs for seeded operands of every length") {
                    let seed: UInt64 = 0x1256
                    var generator = SeededGenerator(state: seed)
                    for dividendWords in 1 ... 4 {
                        for divisorWords in 1 ... 4 {
                            for index in 0 ..< 16 {
                                let dividend = Self.randomMagnitude(words: dividendWords, generator: &generator)
                                let divisor = Self.randomMagnitude(words: divisorWords, generator: &generator)
                                Self.checkDivisionSigns(dividend: dividend, divisor: divisor, description: "seed \(seed), iteration \(index)")
                            }
                        }
                    }
                }

                it("by zero") {
                    expect(captureStandardError {
                        expect {
                            _ = I256(from: [0, 0, 0, 1], signExtend: false) / I256.ZERO
                        }.to(throwAssertion())
                    }).to(contain("Division by zero"))
                }

                it("I256.minValue / 1") {
                    let result = I256.minValue / I256(from: 1)
                    let expected = I256.minValue

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("I256.minValue / -1") {
                    let result = I256.minValue / I256(from: [1, 0, 0, 0], signExtend: true)
                    let expected = I256.minValue

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("by 1") {
                    let i256Value = I256(from: [0, 0, 0, 1], signExtend: false)
                    let result = i256Value / I256(from: 1)
                    let expected = i256Value

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("by -1") {
                    let i256Value = I256(from: [0, 0, 0, 1], signExtend: false)
                    let result = i256Value / I256(from: [1, 0, 0, 0], signExtend: true)
                    let expected = i256Value

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beTrue())
                }

                it("from zero") {
                    let i256Value = I256.ZERO
                    let result = i256Value / I256(from: [1, 0, 0, 0], signExtend: true)
                    let expected = i256Value

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beFalse())
                }

                it("-6 / -2") {
                    let i256Value = I256(from: [6, 0, 0, 0], signExtend: true)
                    let result = i256Value / I256(from: [2, 0, 0, 0], signExtend: true)
                    let expected = I256(from: [3, 0, 0, 0], signExtend: true)

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beFalse())
                }
            }

            context("rem operation") {
                it("returns canonical zero for seeded exact divisions with every sign combination") {
                    let seed: UInt64 = 0x1257
                    var generator = SeededGenerator(state: seed)
                    for words in 1 ... 4 {
                        for index in 0 ..< 16 {
                            let magnitude = Self.randomMagnitude(words: words, generator: &generator)
                            let description = "seed \(seed), iteration \(index)"
                            Self.checkDivisionSigns(dividend: magnitude, divisor: [1, 0, 0, 0], description: description)
                            Self.checkDivisionSigns(dividend: magnitude, divisor: magnitude, description: description)
                            Self.checkDivisionSigns(dividend: [0, 0, 0, 0], divisor: magnitude, description: description)
                        }
                    }
                }

                it("by zero") {
                    expect(captureStandardError {
                        expect {
                            _ = I256(from: [0, 0, 0, 1], signExtend: false) % I256.ZERO
                        }.to(throwAssertion())
                    }).to(contain("Division by zero"))
                }

                it("from zero") {
                    let i256Value = I256(from: [0, 0, 0, 1], signExtend: false)
                    let result = I256.ZERO % i256Value
                    let expected = U256.ZERO

                    expect(result.BYTES).to(equal(expected.BYTES))
                }

                it("9 % 5") {
                    let i256Value = I256(from: 9)
                    let result = i256Value % I256(from: 5)
                    let expected = I256(from: 4)

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beFalse())
                }

                it("-9 % -5") {
                    let i256Value = I256(from: [9, 0, 0, 0], signExtend: true)
                    let result = i256Value % I256(from: [5, 0, 0, 0], signExtend: true)
                    let expected = I256(from: 4)

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beTrue())
                }

                it("-9 % 5") {
                    let i256Value = I256(from: [9, 0, 0, 0], signExtend: true)
                    let result = i256Value % I256(from: [5, 0, 0, 0], signExtend: false)
                    let expected = I256(from: 4)

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beTrue())
                }

                it("9 % -5") {
                    let i256Value = I256(from: [9, 0, 0, 0], signExtend: false)
                    let result = i256Value % I256(from: [5, 0, 0, 0], signExtend: true)
                    let expected = I256(from: 4)

                    expect(result.BYTES).to(equal(expected.BYTES))
                    expect(result.signExtend).to(beFalse())
                }
            }
        }
    }
}
