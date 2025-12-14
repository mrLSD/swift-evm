import Nimble
@testable import PrimitiveTypes
import Quick

final class U512Spec: QuickSpec {
    override class func spec() {
        describe("U512 type") {
            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt64]) {
                    expect(captureStandardError {
                        expect {
                            _ = U512(from: arr)
                        }.to(throwAssertion())
                    }).to(contain("must be initialized with 8 UInt64 values"))
                }

                context("when number of bytes") {
                    it("is Empty") {
                        expectFailInit(array: [])
                    }
                    it("is 7") {
                        expectFailInit(array: [0, 0, 0, 0, 0, 0, 0])
                    }
                    it("is 9") {
                        expectFailInit(array: [0, 0, 0, 0, 0, 0, 0, 0, 0])
                    }
                    it("from Little Endian 65 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = U512.fromLittleEndian(from: [UInt8](repeating: 0, count: 65))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 64 bytes"))
                    }
                    it("from Big Endian 65 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = U512.fromBigEndian(from: [UInt8](repeating: 0, count: 65))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 64 bytes"))
                    }
                }

                context("from U256") {
                    it("too big String") {
                        let a = U256(from: [1, 2, 3, 4])
                        let b = U512(from: a)

                        expect(b.BYTES).to(equal([1, 2, 3, 4, 0, 0, 0, 0]))
                    }
                }

                context("wrong String for conversion") {
                    it("too big String") {
                        expect(captureStandardError {
                            expect {
                                _ = U512.fromString(hex: String(repeating: "A", count: 129))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for 64 bytes"))
                    }
                    it("String length compared to `mod 2`") {
                        expect(captureStandardError {
                            expect {
                                _ = U512.fromString(hex: String(repeating: "A", count: 1))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for `mod 2"))
                    }
                    it("String contains wrong character G") {
                        expect(captureStandardError {
                            expect {
                                _ = U512.fromString(hex: "0G")
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string byte character: 0G"))
                    }
                }
            }

            context("when convert from small numbers") {
                it("correct transformed from Little Endian number 0x01AC") {
                    expect(U512.fromLittleEndian(from: [0x1, 0xAC])).to(equal(U512(from: [0xAC01, 0, 0, 0, 0, 0, 0, 0])))
                }
                it("correct transformed from Big Endian number 0x01AC") {
                    expect(U512.fromBigEndian(from: [0x1, 0xAC])).to(equal(U512(from: [0x01AC, 0, 0, 0, 0, 0, 0, 0])))
                }
            }

            context("when init as MAX value") {
                let val = U512.MAX
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(U512(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
                }
                it("correct transformed from String") {
                    expect(U512.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")).to(equal(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0xFF, count: 64)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0xFF, count: 64)))
                }
                it("correct transformed from Little Endian") {
                    expect(U512.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(U512.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when init as ZERO value") {
                let val = U512.ZERO
                it("correct bytes") {
                    expect(val.BYTES).to(equal([0, 0, 0, 0, 0, 0, 0, 0]))
                }
                it("is Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(U512(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"))
                }
                it("correct transformed from String") {
                    expect(U512.fromString(hex: "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")).to(equal(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0, count: 64)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0, count: 64)))
                }
                it("correct transformed from Little Endian") {
                    expect(U512.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(U512.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when concrete U512 value") {
                it("from Big-Endian") {
                    let val = U512.fromBigEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0xAC, 2,
                    ])
                    expect(0x0000_0000_0000_AC02).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0).to(equal(val.BYTES[3]))
                    expect(0).to(equal(val.BYTES[4]))
                    expect(0).to(equal(val.BYTES[5]))
                    expect(0).to(equal(val.BYTES[6]))
                    expect(0x0F01_0203_C100_0000).to(equal(val.BYTES[7]))
                }
                it("from Little-Endian") {
                    let val = U512.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0xAC, 2,
                    ])
                    expect(0x0000_00C1_0302_010F).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0).to(equal(val.BYTES[3]))
                    expect(0).to(equal(val.BYTES[4]))
                    expect(0).to(equal(val.BYTES[5]))
                    expect(0).to(equal(val.BYTES[6]))
                    expect(0x02AC_0000_0000_0000).to(equal(val.BYTES[7]))
                }

                it("getUInt") {
                    let val = U512.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getUInt).to(beNil())

                    let val2 = U512(from: [0xFFFF, 0, 0, 0, 0, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getUInt))
                }

                it("getInt") {
                    let val = U512.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(val.getInt).to(beNil())

                    let val2 = U512(from: [0xFFFF, 0, 0, 0, 0, 0, 0, 0])
                    expect(0xFFFF).to(equal(val2.getInt))
                }
            }

            context("when compare numbers") {
                it("==") {
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val1 == val2).to(beTrue())
                }

                it("!=") {
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    expect(val1 != val2).to(beTrue())

                    let val3 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val4 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val3 != val4).to(beFalse())
                }

                it("<") {
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    expect(val1 < val2).to(beTrue())

                    let val3 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    let val4 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val3 < val4).to(beFalse())

                    let val5 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val6 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val5 < val6).to(beFalse())
                }

                it(">") {
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val1 > val2).to(beTrue())

                    let val3 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val4 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    expect(val3 > val4).to(beFalse())

                    let val5 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val6 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    expect(val5 > val6).to(beFalse())
                }

                it("<, > combinations") {
                    let lower = U512(from: [0, 0, 0, 0, 0, 0, 0, 1])
                    let higher = U512(from: [0, 0, 0, 0, 0, 0, 0, 2])
                    let equal = U512(from: [0, 0, 0, 0, 0, 0, 0, 1])

                    expect(lower < higher).to(beTrue())
                    expect(higher > lower).to(beTrue())
                    expect(lower < equal).to(beFalse())
                    expect(equal > higher).to(beFalse())
                }

                it("edge cases") {
                    let zero = U512.ZERO
                    let max = U512.MAX
                    let one = U512(from: UInt64(1))
                    let nearMax = U512(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max - 1])

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
                    let anotherMax = U512.MAX
                    expect(max == anotherMax).to(beTrue())
                    expect(max > anotherMax).to(beFalse())
                    expect(max < anotherMax).to(beFalse())
                }

                it("<=") {
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    let val3 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val4 = U512(from: [0, 0, 0, 0, 0, 0, 0, 0])
                    let val5 = U512(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max])

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
                    let val1 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    let val2 = U512(from: [1, 2, 3, 4, 5, 6, 7, 8])
                    let val3 = U512(from: [1, 2, 3, 4, 5, 6, 7, 9])
                    let val4 = U512(from: [0, 0, 0, 0, 0, 0, 0, 0])
                    let val5 = U512(from: [UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max, UInt64.max])

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
