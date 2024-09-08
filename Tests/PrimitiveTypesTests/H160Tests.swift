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
                        expect(captureStandardError {
                            expect {
                                _ = H160.fromString(hex: String(repeating: "A", count: 41))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for 20 bytes"))
                    }
                    it("String length to compared to `mod 2`") {
                        expect(captureStandardError {
                            expect {
                                _ = H160.fromString(hex: String(repeating: "A", count: 1))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for `mod 2"))
                    }
                    it("String contains wrong character G") {
                        expect(captureStandardError {
                            expect {
                                _ = H160.fromString(hex: "0G")
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string byte character: 0G"))
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
                        expect("\(val)").to(equal("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
                    }
                    it("correct transformed from String") {
                        expect(H160.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")).to(equal(val))
                    }
                }

                context("when init as ZERO value") {
                    let val = H160.ZERO
                    it("correct bytes") {
                        expect(val.BYTES).to(equal([UInt8](repeating: 0, count: 20)))
                    }
                    it("not Zero value") {
                        expect(val.isZero).to(beTrue())
                    }
                    it("correct transformed to String") {
                        expect("\(val)").to(equal("0000000000000000000000000000000000000000"))
                    }
                    it("correct transformed from String") {
                        expect(H160.fromString(hex: "0000000000000000000000000000000000000000")).to(equal(val))
                    }
                }
            }
        }
    }
}
