import Nimble
@testable import PrimitiveTypes
import Quick

final class U256Spec: QuickSpec {
    override class func spec() {
        describe("U256 type") {
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
                    it("is 3") {
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

                context("wrong String for conversion") {
                    it("too big String") {
                        expect(captureStandardError {
                            expect {
                                _ = U256.fromString(hex: String(repeating: "A", count: 65))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for 32 bytes"))
                    }
                    it("String length to compared to `mod 2`") {
                        expect(captureStandardError {
                            expect {
                                _ = U256.fromString(hex: String(repeating: "A", count: 1))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for `mod 2"))
                    }
                    it("String contains wrong character G") {
                        expect(captureStandardError {
                            expect {
                                _ = U256.fromString(hex: "0G")
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string byte character: 0G"))
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
                    expect("\(val)").to(equal("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
                }
                it("correct transformed from String") {
                    expect(U256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")).to(equal(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0xFF, count: 32)))
                }
                it("correct transformed to Bit Endian array") {
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
                it("not Zero value") {
                    expect(val.isZero).to(beTrue())
                }
                it("not u64 MAX") {
                    expect(val).toNot(equal(U256(from: UInt64.max)))
                }
                it("correct transformed to String") {
                    expect("\(val)").to(equal("0000000000000000000000000000000000000000000000000000000000000000"))
                }
                it("correct transformed from String") {
                    expect(U256.fromString(hex: "0000000000000000000000000000000000000000000000000000000000000000")).to(equal(val))
                }
                it("correct transformed to Little Endian array") {
                    expect(val.toLittleEndian).to(equal([UInt8](repeating: 0, count: 32)))
                }
                it("correct transformed to Bit Endian array") {
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
                    expect(0x0000_0000_0000_AC02).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x0F01_0203_C100_0000).to(equal(val.BYTES[3]))
                }
                it("from Little-Endian") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x0000_00C1_0302_010F).to(equal(val.BYTES[0]))
                    expect(0).to(equal(val.BYTES[1]))
                    expect(0).to(equal(val.BYTES[2]))
                    expect(0x02AC_0000_0000_0000).to(equal(val.BYTES[3]))
                }

                it("getUInt") {
                    let val = U256.fromLittleEndian(from: [
                        0xF, 1, 2, 3, 0xC1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0xAC, 2,
                    ])
                    expect(0x0000_00C1_0302_010F).to(equal(val.getUInt))
                }
            }
        }
    }
}
