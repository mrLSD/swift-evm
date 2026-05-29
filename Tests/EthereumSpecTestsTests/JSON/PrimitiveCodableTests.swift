@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class PrimitiveCodableSpec: QuickSpec {
    override class func spec() {
        describe("Decodable conformances for primitive types") {
            let decoder = JSONDecoder()

            context("U256 Decodable") {
                struct W: Decodable { let v: U256 }

                it("decodes from canonical hex string") {
                    let json = #"{"v":"0x10"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).v).to(equal(U256(from: 16)))
                }
                it("decodes empty 0x as ZERO") {
                    let json = #"{"v":"0x"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).v.isZero).to(beTrue())
                }
                it("propagates a useful error on invalid hex") {
                    let json = #"{"v":"0xnope"}"#.data(using: .utf8)!
                    expect { try decoder.decode(W.self, from: json) }.to(throwError { (e: Error) in
                        expect(String(describing: e)).to(contain("U256"))
                    })
                }
            }

            context("U128 Decodable") {
                struct W: Decodable { let v: U128 }

                it("decodes from canonical hex string") {
                    let json = #"{"v":"0xff"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).v).to(equal(U128(from: 0xff)))
                }
                it("propagates error on overflow") {
                    let s = "0x" + String(repeating: "ff", count: 17)
                    let json = #"{"v":"\#(s)"}"#.data(using: .utf8)!
                    expect { try decoder.decode(W.self, from: json) }.to(throwError { (e: Error) in
                        expect(String(describing: e)).to(contain("U128"))
                    })
                }
            }

            context("H160 Decodable") {
                struct W: Decodable { let v: H160 }

                it("decodes a full 20-byte address") {
                    let json = #"{"v":"0x000000000000000000000000000000000000001f"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).v.BYTES.last).to(equal(0x1f))
                }
                it("left-pads short addresses (tolerant)") {
                    let json = #"{"v":"0x01"}"#.data(using: .utf8)!
                    let h = try! decoder.decode(W.self, from: json).v
                    expect(h.BYTES.last).to(equal(0x01))
                    expect(h.BYTES.dropLast().allSatisfy { $0 == 0 }).to(beTrue())
                }
                it("propagates error on too-wide hex") {
                    let s = "0x" + String(repeating: "ab", count: 21)
                    let json = #"{"v":"\#(s)"}"#.data(using: .utf8)!
                    expect { try decoder.decode(W.self, from: json) }.to(throwError { (e: Error) in
                        expect(String(describing: e)).to(contain("H160"))
                    })
                }
            }

            context("H256 Decodable") {
                struct W: Decodable { let v: H256 }

                it("left-pads short hash hex (tolerant)") {
                    let json = #"{"v":"0x01"}"#.data(using: .utf8)!
                    let h = try! decoder.decode(W.self, from: json).v
                    expect(h.BYTES.last).to(equal(0x01))
                    expect(h.BYTES.dropLast().allSatisfy { $0 == 0 }).to(beTrue())
                }
                it("decodes full 32-byte hash unchanged") {
                    let s = "0x" + String(repeating: "ab", count: 32)
                    let json = #"{"v":"\#(s)"}"#.data(using: .utf8)!
                    let h = try! decoder.decode(W.self, from: json).v
                    expect(h.BYTES.allSatisfy { $0 == 0xab }).to(beTrue())
                }
                it("propagates error on too-wide hex") {
                    let s = "0x" + String(repeating: "ab", count: 33)
                    let json = #"{"v":"\#(s)"}"#.data(using: .utf8)!
                    expect { try decoder.decode(W.self, from: json) }.to(throwError { (e: Error) in
                        expect(String(describing: e)).to(contain("H256"))
                    })
                }
            }
        }
    }
}
