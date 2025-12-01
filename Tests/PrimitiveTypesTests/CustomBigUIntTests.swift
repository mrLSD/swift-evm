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

        public init(from value: [UInt64]) {
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
                            let _ = TestUint128(from: arr)
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
                        expect(captureStandardError {
                            expect {
                                _ = TestUint128.fromString(hex: String(repeating: "A", count: 33))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for 16 bytes"))
                    }
                    it("String length to compared to `mod 2`") {
                        expect(captureStandardError {
                            expect {
                                _ = TestUint128.fromString(hex: String(repeating: "A", count: 1))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for `mod 2"))
                    }
                    it("String contains wrong character G") {
                        expect(captureStandardError {
                            expect {
                                _ = TestUint128.fromString(hex: "0G")
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string byte character: 0G"))
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
                    expect("\(val)").to(equal("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
                }
                it("correct transformed from String") {
                    expect(TestUint128.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")).to(equal(val))
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
                    expect("\(val)").to(equal("00000000000000000000000000000000"))
                }
                it("correct transformed from String") {
                    expect(TestUint128.fromString(hex: "00000000000000000000000000000000")).to(equal(val))
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
        }
    }
}
