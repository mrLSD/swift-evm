@testable import EthereumSpecTests
import Nimble
import PrimitiveTypes
import Quick

final class HexParserSpec: QuickSpec {
    override class func spec() {
        describe("HexParser type") {
            context("decodeBytes") {
                it("strips 0x prefix") {
                    expect(try! HexParser.decodeBytes("0xff01")).to(equal([0xff, 0x01]))
                }
                it("accepts uppercase 0X prefix") {
                    expect(try! HexParser.decodeBytes("0XFf01")).to(equal([0xff, 0x01]))
                }
                it("accepts no prefix") {
                    expect(try! HexParser.decodeBytes("ff01")).to(equal([0xff, 0x01]))
                }
                it("returns empty for 0x") {
                    expect(try! HexParser.decodeBytes("0x")).to(equal([]))
                }
                it("returns empty for empty string") {
                    expect(try! HexParser.decodeBytes("")).to(equal([]))
                }
                it("left-pads odd-length hex with single 0") {
                    expect(try! HexParser.decodeBytes("0x1")).to(equal([0x01]))
                    expect(try! HexParser.decodeBytes("0x1ab")).to(equal([0x01, 0xab]))
                }
                it("rejects invalid hex characters") {
                    expect { try HexParser.decodeBytes("0xZZ") }
                        .to(throwError(HexStringError.InvalidHexCharacter("ZZ")))
                }
            }

            context("parseU256") {
                it("parses zero from empty hex") {
                    expect(try! HexParser.parseU256("0x").isZero).to(beTrue())
                }
                it("parses zero from empty string") {
                    expect(try! HexParser.parseU256("").isZero).to(beTrue())
                }
                it("parses small value") {
                    expect(try! HexParser.parseU256("0x01")).to(equal(U256(from: 1)))
                }
                it("parses full 32-byte MAX value") {
                    let s = "0x" + String(repeating: "ff", count: 32)
                    expect(try! HexParser.parseU256(s)).to(equal(U256.MAX))
                }
                it("rejects values wider than 32 bytes") {
                    let s = "0x" + String(repeating: "ff", count: 33)
                    expect { try HexParser.parseU256(s) }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }

            context("parseU128") {
                it("parses zero") {
                    expect(try! HexParser.parseU128("0x").isZero).to(beTrue())
                }
                it("parses small value") {
                    expect(try! HexParser.parseU128("0xab")).to(equal(U128(from: 0xab)))
                }
                it("rejects values wider than 16 bytes") {
                    let s = "0x" + String(repeating: "ab", count: 17)
                    expect { try HexParser.parseU128(s) }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }

            context("parseH160") {
                it("parses full 20-byte address") {
                    let v = try! HexParser.parseH160("0x000000000000000000000000000000000000abcd")
                    expect(v.BYTES.last).to(equal(0xcd))
                    expect(v.BYTES.dropLast().last).to(equal(0xab))
                }
                it("left-pads short addresses") {
                    let v = try! HexParser.parseH160("0x01")
                    expect(v.BYTES.count).to(equal(20))
                    expect(v.BYTES.last).to(equal(0x01))
                    expect(v.BYTES.dropLast().allSatisfy { $0 == 0 }).to(beTrue())
                }
                it("returns ZERO for empty hex") {
                    expect(try! HexParser.parseH160("0x")).to(equal(H160.ZERO))
                }
                it("rejects values wider than 20 bytes") {
                    let s = "0x" + String(repeating: "ab", count: 21)
                    expect { try HexParser.parseH160(s) }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }

            context("parseH256") {
                it("parses full 32-byte hash") {
                    let s = "0x" + String(repeating: "ab", count: 32)
                    let v = try! HexParser.parseH256(s)
                    expect(v.BYTES.allSatisfy { $0 == 0xab }).to(beTrue())
                }
                it("left-pads short hash") {
                    let v = try! HexParser.parseH256("0x01")
                    expect(v.BYTES.count).to(equal(32))
                    expect(v.BYTES.last).to(equal(0x01))
                    expect(v.BYTES.dropLast().allSatisfy { $0 == 0 }).to(beTrue())
                }
                it("returns ZERO for empty hex") {
                    expect(try! HexParser.parseH256("0x")).to(equal(H256.ZERO))
                }
                it("rejects values wider than 32 bytes") {
                    let s = "0x" + String(repeating: "ab", count: 33)
                    expect { try HexParser.parseH256(s) }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }

            context("parseUInt8") {
                it("parses zero from empty hex") {
                    expect(try! HexParser.parseUInt8("0x")).to(equal(0))
                }
                it("parses single byte") {
                    expect(try! HexParser.parseUInt8("0x42")).to(equal(0x42))
                    expect(try! HexParser.parseUInt8("0xff")).to(equal(0xff))
                }
                it("rejects values wider than 1 byte") {
                    expect { try HexParser.parseUInt8("0x0100") }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }

            context("parseUInt64") {
                it("parses zero from empty hex") {
                    expect(try! HexParser.parseUInt64("0x")).to(equal(0))
                }
                it("parses small value") {
                    expect(try! HexParser.parseUInt64("0x01")).to(equal(1))
                }
                it("parses big-endian multi-byte value") {
                    expect(try! HexParser.parseUInt64("0x0102")).to(equal(0x0102))
                }
                it("parses 8-byte max") {
                    expect(try! HexParser.parseUInt64("0xffffffffffffffff")).to(equal(UInt64.max))
                }
                it("rejects 9-byte input") {
                    expect { try HexParser.parseUInt64("0x010000000000000000") }
                        .to(throwError(HexStringError.InvalidStringLength))
                }
            }
        }
    }
}
