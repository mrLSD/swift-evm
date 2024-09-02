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
                        expectFailInit(array: [UInt8](repeating: 0, count: 19))
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
            }
        }
    }
}
