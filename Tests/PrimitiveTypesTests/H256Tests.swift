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
                        expect(captureStandardError {
                            expect {
                                _ = H256.fromString(hex: String(repeating: "A", count: 65))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for 32 bytes"))
                    }
                    it("String length to compared to `mod 2`") {
                        expect(captureStandardError {
                            expect {
                                _ = H256.fromString(hex: String(repeating: "A", count: 1))
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string for `mod 2"))
                    }
                    it("String contains wrong character G") {
                        expect(captureStandardError {
                            expect {
                                _ = H256.fromString(hex: "0G")
                            }.to(throwAssertion())
                        }).to(contain("Invalid hex string byte character: 0G"))
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
                        expect("\(val)").to(equal("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
                    }
                    it("correct transformed from String") {
                        expect(H256.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")).to(equal(val))
                    }
                }

                context("when init as ZERO value") {
                    let val = H256.ZERO
                    it("correct bytes") {
                        expect(val.BYTES).to(equal([UInt8](repeating: 0, count: 32)))
                    }
                    it("not Zero value") {
                        expect(val.isZero).to(beTrue())
                    }
                    it("correct transformed to String") {
                        expect("\(val)").to(equal("0000000000000000000000000000000000000000000000000000000000000000"))
                    }
                    it("correct transformed from String") {
                        expect(H256.fromString(hex: "0000000000000000000000000000000000000000000000000000000000000000")).to(equal(val))
                    }
                }

                context("when init from H160 value") {
                    let valH160 = H160(from: [UInt8](repeating: 0xAC, count: 20))
                    let val = H256(from: valH160)

                    it("correct data") {
                        expect(val.BYTES).to(equal([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC]))
                    }

                    it("correct leading zero") {
                        expect(Array(val.BYTES[..<12]))
                            .to(equal([UInt8](repeating: 0, count: 12)))
                    }
                }

                context("when converted to H160 value") {
                    it("correct data") {
                        let valH160 = H160(from: [UInt8](repeating: 0xAC, count: 20))
                        let val = H256(from: valH160)

                        expect(val.BYTES).to(equal([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC, 0xAC]))
                        expect(val.toH160()).to(equal(valH160))
                    }
                }

                context("when hashing H256") {
                    it("produces the same hash for equal values") {
                        let bytes = [UInt8](repeating: 0xAB, count: 32)
                        let h1 = H256(from: bytes)
                        let h2 = H256(from: bytes)

                        expect(h1.hashValue).to(equal(h2.hashValue))
                    }

                    it("produces different hash for different values") {
                        let h1 = H256(from: [UInt8](repeating: 0x00, count: 32))
                        let h2 = H256(from: [UInt8](repeating: 0x01, count: 32))

                        expect(h1.hashValue).toNot(equal(h2.hashValue))
                    }

                    it("can be used in a Set") {
                        let h1 = H256(from: [UInt8](repeating: 0x01, count: 32))
                        let h2 = H256(from: [UInt8](repeating: 0x02, count: 32))
                        let h3 = H256(from: [UInt8](repeating: 0x01, count: 32)) // same as h1

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
}
