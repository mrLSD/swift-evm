import Nimble
@testable import PrimitiveTypes
import Quick

final class HexEncodingSpec: QuickSpec {
    override class func spec() {
        describe("HexEncoding helpers") {
            context("hexByteAscii") {
                it("lowercase nibbles") {
                    expect(hexByteAscii(0x00, uppercase: false) == (0x30, 0x30)).to(beTrue()) // "00"
                    expect(hexByteAscii(0xAB, uppercase: false) == (0x61, 0x62)).to(beTrue()) // "ab"
                    expect(hexByteAscii(0xFF, uppercase: false) == (0x66, 0x66)).to(beTrue()) // "ff"
                    expect(hexByteAscii(0x5A, uppercase: false) == (0x35, 0x61)).to(beTrue()) // "5a"
                }

                it("uppercase nibbles") {
                    expect(hexByteAscii(0x00, uppercase: true) == (0x30, 0x30)).to(beTrue()) // "00"
                    expect(hexByteAscii(0xAB, uppercase: true) == (0x41, 0x42)).to(beTrue()) // "AB"
                    expect(hexByteAscii(0xFF, uppercase: true) == (0x46, 0x46)).to(beTrue()) // "FF"
                    expect(hexByteAscii(0x5A, uppercase: true) == (0x35, 0x41)).to(beTrue()) // "5A"
                }
            }

            context("hexEncode") {
                it("empty input produces empty string") {
                    expect(hexEncode([UInt8](), uppercase: false)).to(equal(""))
                }

                it("distinct bytes preserve order lowercase") {
                    let bytes: [UInt8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
                    expect(hexEncode(bytes, uppercase: false)).to(equal("0123456789abcdef"))
                }

                it("distinct bytes preserve order uppercase") {
                    let bytes: [UInt8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
                    expect(hexEncode(bytes, uppercase: true)).to(equal("0123456789ABCDEF"))
                }

                it("single zero byte") {
                    expect(hexEncode([UInt8(0)], uppercase: false)).to(equal("00"))
                    expect(hexEncode([UInt8(0)], uppercase: true)).to(equal("00"))
                }

                it("max byte") {
                    expect(hexEncode([UInt8.max], uppercase: false)).to(equal("ff"))
                    expect(hexEncode([UInt8.max], uppercase: true)).to(equal("FF"))
                }
            }

            context("hexEncodeNoPad") {
                it("zero returns single '0'") {
                    expect(hexEncodeNoPad(0, uppercase: false)).to(equal("0"))
                    expect(hexEncodeNoPad(0, uppercase: true)).to(equal("0"))
                }

                it("single nibble values have no leading zero") {
                    expect(hexEncodeNoPad(1, uppercase: false)).to(equal("1"))
                    expect(hexEncodeNoPad(0xa, uppercase: false)).to(equal("a"))
                    expect(hexEncodeNoPad(0xA, uppercase: true)).to(equal("A"))
                    expect(hexEncodeNoPad(0xF, uppercase: false)).to(equal("f"))
                    expect(hexEncodeNoPad(0xF, uppercase: true)).to(equal("F"))
                }

                it("multi-byte values strip leading zeros") {
                    expect(hexEncodeNoPad(0x10, uppercase: false)).to(equal("10"))
                    expect(hexEncodeNoPad(0xabcd, uppercase: false)).to(equal("abcd"))
                    expect(hexEncodeNoPad(0xabcd, uppercase: true)).to(equal("ABCD"))
                    expect(hexEncodeNoPad(0xdead_beef, uppercase: false)).to(equal("deadbeef"))
                }

                it("UInt64.max — full-width hex without leading zeros") {
                    expect(hexEncodeNoPad(UInt64.max, uppercase: false)).to(equal("ffffffffffffffff"))
                    expect(hexEncodeNoPad(UInt64.max, uppercase: true)).to(equal("FFFFFFFFFFFFFFFF"))
                }

                it("value with internal zero nibble") {
                    // 0x1020304050607080 — каждый 2-й nibble нулевой; проверяем что order сохраняется.
                    expect(hexEncodeNoPad(0x1020_3040_5060_7080, uppercase: false)).to(equal("1020304050607080"))
                }
            }
        }
    }
}
