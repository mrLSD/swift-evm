@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class RLPSpec: QuickSpec {
    override class func spec() {
        describe("RLP encoder") {
            context("encodeBytes") {
                it("encodes a single byte 0x00..0x7f as itself") {
                    expect(RLP.encodeBytes([0x00])).to(equal([0x00]))
                    expect(RLP.encodeBytes([0x7f])).to(equal([0x7f]))
                }
                it("encodes a single byte 0x80..0xff with length prefix") {
                    expect(RLP.encodeBytes([0x80])).to(equal([0x81, 0x80]))
                    expect(RLP.encodeBytes([0xff])).to(equal([0x81, 0xff]))
                }
                it("encodes the empty string as 0x80") {
                    expect(RLP.encodeBytes([])).to(equal([0x80]))
                }
                it("encodes 'dog' (3 bytes) as 0x83 0x64 0x6f 0x67") {
                    expect(RLP.encodeBytes(Array("dog".utf8))).to(equal([0x83, 0x64, 0x6f, 0x67]))
                }
                it("encodes a 55-byte string with single-byte short-form prefix") {
                    let bytes = [UInt8](repeating: 0xab, count: 55)
                    let encoded = RLP.encodeBytes(bytes)
                    expect(encoded.first).to(equal(0x80 + 55))
                    expect(encoded.count).to(equal(56))
                }
                it("encodes a 56-byte string with the long-form prefix 0xb8") {
                    let bytes = [UInt8](repeating: 0xab, count: 56)
                    let encoded = RLP.encodeBytes(bytes)
                    expect(encoded[0]).to(equal(0xb8))
                    expect(encoded[1]).to(equal(56))
                    expect(encoded.count).to(equal(58))
                }
                it("encodes a 256-byte string with the 2-byte length prefix 0xb9") {
                    let bytes = [UInt8](repeating: 0xab, count: 256)
                    let encoded = RLP.encodeBytes(bytes)
                    expect(encoded[0]).to(equal(0xb9))
                    expect(encoded[1]).to(equal(0x01))
                    expect(encoded[2]).to(equal(0x00))
                    expect(encoded.count).to(equal(259))
                }
            }

            context("encodeList") {
                it("encodes the empty list as 0xc0") {
                    expect(RLP.encodeList([])).to(equal([0xc0]))
                }
                it("encodes ['cat','dog']") {
                    let cat = RLP.encodeBytes(Array("cat".utf8))
                    let dog = RLP.encodeBytes(Array("dog".utf8))
                    expect(RLP.encodeList([cat, dog]))
                        .to(equal([0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67]))
                }
                it("encodes a list whose payload is > 55 bytes with long-form prefix") {
                    let big = [UInt8](repeating: 0xab, count: 60)
                    let item = RLP.encodeBytes(big)
                    let encoded = RLP.encodeList([item])
                    expect(encoded[0]).to(equal(0xf8))
                    expect(encoded[1]).to(equal(UInt8(item.count)))
                }
            }

            context("encodeU256") {
                it("encodes ZERO as the empty-string sentinel 0x80") {
                    expect(RLP.encodeU256(U256.ZERO)).to(equal([0x80]))
                }
                it("encodes 1 as 0x01") {
                    expect(RLP.encodeU256(U256(from: 1))).to(equal([0x01]))
                }
                it("encodes 0x80 as 0x81 0x80 — the high bit forces a length prefix") {
                    expect(RLP.encodeU256(U256(from: 128))).to(equal([0x81, 0x80]))
                }
                it("encodes 1024 as 0x82 0x04 0x00") {
                    expect(RLP.encodeU256(U256(from: 1024))).to(equal([0x82, 0x04, 0x00]))
                }
            }

            context("encodeUInt64") {
                it("encodes zero as 0x80") {
                    expect(RLP.encodeUInt64(0)).to(equal([0x80]))
                }
                it("encodes 1 as 0x01") {
                    expect(RLP.encodeUInt64(1)).to(equal([0x01]))
                }
                it("encodes UInt64.max as the full 8-byte big-endian sequence") {
                    expect(RLP.encodeUInt64(UInt64.max))
                        .to(equal([0x88, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]))
                }
            }

            context("encodeH256 / encodeH160") {
                it("encodes H256 as a 33-byte sequence (0xa0 + 32 bytes)") {
                    let encoded = RLP.encodeH256(h256LastByte(0x01))
                    expect(encoded[0]).to(equal(0xa0))
                    expect(encoded.count).to(equal(33))
                }
                it("encodes H160 as a 21-byte sequence (0x94 + 20 bytes)") {
                    let encoded = RLP.encodeH160(h160LastByte(0x01))
                    expect(encoded[0]).to(equal(0x94))
                    expect(encoded.count).to(equal(21))
                }
            }
        }

        describe("TrieAccount.rlpEncoded") {
            it("uses the 4-tuple short form when codeVersion == 0") {
                let acc = TrieAccount(
                    nonce: U256.ZERO,
                    balance: U256.ZERO,
                    storageRoot: StateRootHasher.emptyTrieRoot,
                    codeHash: H256(from: [UInt8](repeating: 0xab, count: 32)),
                    codeVersion: U256.ZERO
                )
                let encoded = acc.rlpEncoded()
                expect(encoded[0]).to(equal(0xf8))
                expect(encoded[1]).to(equal(68))
                expect(encoded[2]).to(equal(0x80))
                expect(encoded[3]).to(equal(0x80))
                expect(encoded[4]).to(equal(0xa0))
            }

            it("uses the 5-tuple long form when codeVersion != 0") {
                let acc = TrieAccount(
                    nonce: U256(from: 1),
                    balance: U256(from: 100),
                    storageRoot: StateRootHasher.emptyTrieRoot,
                    codeHash: H256(from: [UInt8](repeating: 0xab, count: 32)),
                    codeVersion: U256(from: 7)
                )
                let encoded = acc.rlpEncoded()
                expect(encoded[0]).to(equal(0xf8))
                expect(encoded[1]).to(equal(69))
            }
        }
    }
}
