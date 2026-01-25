import Nimble
@testable import PrimitiveTypes
import Quick

final class I256Spec: QuickSpec {
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
            }

            context("div operation") {
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
