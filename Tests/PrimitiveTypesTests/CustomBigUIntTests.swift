import Nimble
@testable import PrimitiveTypes
import Quick

final class BigUintSpec: QuickSpec {
    struct TestUint128: BigUInt {
        private let bytes: [UInt64]
        static let numberBytes: UInt8 = 16
        var BYTES: [UInt64] { bytes }
        static let MAX: Self = getMax
        static let ZERO: Self = getZero

        init(from value: [UInt64]) {
            precondition(value.count == Self.numberBase, "BigUInt must be initialized with \(Self.numberBase) UInt64 values.")
            self.bytes = value
        }
    }

    override class func spec() {
        describe("BigUInt custom type: TestUint128") {
            context("when init data wrong panics with message") {
                func expectFailInit(array arr: [UInt64]) {
                    let errorMessage = captureStandardError {
                        expect {
                            _ = TestUint128(from: arr)
                        }.to(throwAssertion())
                    }
                    expect(errorMessage).to(contain("must be initialized with 2 UInt64 values"))
                }

                context("when number of bytes") {
                    it("is Empty") {
                        expectFailInit(array: [])
                    }
                    it("is 1") {
                        expectFailInit(array: [0])
                    }
                    it("is 3") {
                        expectFailInit(array: [0, 0, 0])
                    }
                    it("from Little Endian 17 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = TestUint128.fromLittleEndian(from: [UInt8](repeating: 0, count: 17))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 16 bytes"))
                    }
                    it("from Big Endian 17 bytes") {
                        expect(captureStandardError {
                            expect {
                                _ = TestUint128.fromBigEndian(from: [UInt8](repeating: 0, count: 17))
                            }.to(throwAssertion())
                        }).to(contain("must be initialized with not more than 16 bytes"))
                    }
                }

                context("wrong String for conversion") {
                    it("too big String") {
                        let res = TestUint128.fromString(hex: String(repeating: "A", count: 33))
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidStringLength))
                        })
                    }
                    it("String length compared to `mod 2`") {
                        let res = TestUint128.fromString(hex: String(repeating: "A", count: 1))
                        expect(res).to(beSuccess(TestUint128(from: 0xA)))
                    }
                    it("String contains wrong character G") {
                        let res = TestUint128.fromString(hex: "0G")
                        expect(res).to(beFailure { error in
                            expect(error).to(matchError(HexStringError.InvalidHexCharacter("0G")))
                        })
                    }
                }
            }

            context("when convert from small numbers") {
                it("correct transformed from Little Endian number 0x01AC") {
                    expect(TestUint128.fromLittleEndian(from: [0x1, 0xAC])).to(equal(TestUint128(from: [0xAC01, 0])))
                }
                it("correct transformed from Big Endian number 0x01AC") {
                    expect(TestUint128.fromBigEndian(from: [0x1, 0xAC])).to(equal(TestUint128(from: [0x01AC, 0])))
                }
            }

            context("when init as MAX value") {
                let val = TestUint128.MAX
                it("correct bytes") {
                    expect(val.BYTES).to(equal([UInt64.max, UInt64.max]))
                }
                it("not Zero value") {
                    expect(val.isZero).to(beFalse())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(TestUint128(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("ffffffffffffffffffffffffffffffff"))
                }
                it("correct transformed from String") {
                    let res = TestUint128.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
                    expect(res).to(beSuccess { value in
                        expect(value).to(equal(val))
                    })
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0xFF, count: 16)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0xFF, count: 16)))
                }
                it("correct transformed from Little Endian") {
                    expect(TestUint128.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(TestUint128.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("when init as ZERO value") {
                let val = TestUint128.ZERO
                it("correct bytes") {
                    expect(val.BYTES).to(equal([0, 0]))
                }
                it("is Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(TestUint128(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("0"))
                }
                it("correct transformed from String") {
                    let res = TestUint128.fromString(hex: "00000000000000000000000000000000")
                    expect(res).to(beSuccess(val))
                }

                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0, count: 16)))
                }
                it("correct transformed to Big Endian array") {
                    expect(val.toBigEndian).to(equal([UInt8](repeating: 0, count: 16)))
                }
                it("correct transformed from Little Endian") {
                    expect(TestUint128.fromLittleEndian(from: val.toLittleEndian)).to(equal(val))
                }
                it("correct transformed from Big Endian") {
                    expect(TestUint128.fromBigEndian(from: val.toBigEndian)).to(equal(val))
                }
            }

            context("wrong String number overflow") {
                it("too big String with overflow") {
                    let hex = String(repeating: "A", count: 34)
                    let res = TestUint128.fromString(hex: hex)
                    expect(res).to(beFailure { error in
                        expect(error).to(matchError(HexStringError.InvalidStringLength))
                    })
                }

                it("leading zeros + 32 'A' characters should fail") {
                    // Prepend 4 hex zeros (2 bytes) to a 32-'A' hex string.
                    let trimmed = String(repeating: "A", count: 32)
                    let hex = "0000" + trimmed

                    // Parsing must fail due to invalid length.
                    let res = TestUint128.fromString(hex: hex)
                    expect(res).to(beFailure { error in
                        expect(error).to(matchError(HexStringError.InvalidStringLength))
                    })
                }

                context("Different hex variants") {
                    it("String with 0x prefix") {
                        let hex = "0xAC"
                        let res = TestUint128.fromString(hex: hex)
                        expect(res).to(beSuccess(TestUint128(from: 0xAC)))
                    }

                    it("Empty string") {
                        let res1 = TestUint128.fromString(hex: "0x")
                        let res2 = TestUint128.fromString(hex: "")
                        expect(res1).to(beSuccess(TestUint128.ZERO))
                        expect(res2).to(beSuccess(TestUint128.ZERO))
                    }

                    it("Encode gex to upper case") {
                        let res = TestUint128(from: 0xAC).encodeHexUpper()
                        let res2 = TestUint128(from: 0xAC).encodeHexLower()
                        expect(res).to(equal("AC"))
                        expect(res2.uppercased()).to(equal(res))
                    }
                }
            }
        }
    }
}
