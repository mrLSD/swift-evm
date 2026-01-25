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
                    it("produces the same hash for equal values") {
                        let bytes = [UInt8](repeating: 0xab, count: 20)
                        let h1 = H160(from: bytes)
                        let h2 = H160(from: bytes)

                        expect(h1.hashValue).to(equal(h2.hashValue))
                    }

                    it("can be used in a Set") {
                        let h1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                        let h2 = H160(from: [UInt8](repeating: 0x02, count: 20))
                        let h3 = H160(from: [UInt8](repeating: 0x01, count: 20)) // same as h1

                        var set: Set<H160> = []
                        set.insert(h1)
                        set.insert(h2)
                        set.insert(h3)

                        expect(set.count).to(equal(2))
                        expect(set.contains(h1)).to(beTrue())
                        expect(set.contains(h2)).to(beTrue())
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
