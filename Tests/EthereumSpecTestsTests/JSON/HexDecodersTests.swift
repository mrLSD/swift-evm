@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

private struct Sample: Decodable {
    let bytes: [UInt8]
    let optionalBytes: [UInt8]?
    let absent: [UInt8]?
    let txType: UInt8?
    let absentTxType: UInt8?
    let strictTxType: UInt8
    let nonce: UInt64
    let optionalNonce: UInt64?
    let absentNonce: UInt64?
    let datas: [[UInt8]]
    let values: [U256]
    let storage: [H256: H256]

    enum CodingKeys: String, CodingKey {
        case bytes, optionalBytes, absent
        case txType, absentTxType, strictTxType
        case nonce, optionalNonce, absentNonce
        case datas, values, storage
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        self.bytes = try c.decodeHexBytes(forKey: .bytes)
        self.optionalBytes = try c.decodeHexBytesIfPresent(forKey: .optionalBytes)
        self.absent = try c.decodeHexBytesIfPresent(forKey: .absent)
        self.txType = try c.decodeHexUInt8IfPresent(forKey: .txType)
        self.absentTxType = try c.decodeHexUInt8IfPresent(forKey: .absentTxType)
        self.strictTxType = try c.decodeHexUInt8(forKey: .strictTxType)
        self.nonce = try c.decodeHexUInt64(forKey: .nonce)
        self.optionalNonce = try c.decodeHexUInt64IfPresent(forKey: .optionalNonce)
        self.absentNonce = try c.decodeHexUInt64IfPresent(forKey: .absentNonce)
        self.datas = try c.decodeHexBytesArray(forKey: .datas)
        self.values = try c.decodeHexU256Array(forKey: .values)
        self.storage = try c.decodeStorageMap(forKey: .storage)
    }
}

final class HexDecodersSpec: QuickSpec {
    override class func spec() {
        describe("KeyedDecodingContainer hex helpers") {
            let decoder = JSONDecoder()

            context("happy path") {
                it("decodes the full sample shape") {
                    let json = #"""
                    {
                      "bytes": "0xdeadbeef",
                      "optionalBytes": "0x01",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "optionalNonce": "0x05",
                      "datas": ["0x01", "0xabcd"],
                      "values": ["0x", "0x10", "0xff"],
                      "storage": { "0x01": "0x02", "0x0a": "0x0b" }
                    }
                    """#.data(using: .utf8)!
                    let s = try! decoder.decode(Sample.self, from: json)
                    expect(s.bytes).to(equal([0xde, 0xad, 0xbe, 0xef]))
                    expect(s.optionalBytes).to(equal([0x01]))
                    expect(s.absent).to(beNil())
                    expect(s.txType).to(equal(0x02))
                    expect(s.absentTxType).to(beNil())
                    expect(s.strictTxType).to(equal(0x03))
                    expect(s.nonce).to(equal(0x10))
                    expect(s.optionalNonce).to(equal(0x05))
                    expect(s.absentNonce).to(beNil())
                    expect(s.datas).to(equal([[0x01], [0xab, 0xcd]]))
                    expect(s.values.count).to(equal(3))
                    expect(s.values[0].isZero).to(beTrue())
                    expect(s.values[1]).to(equal(U256(from: 16)))
                    expect(s.storage.count).to(equal(2))
                    expect(s.storage.keys.map { $0.BYTES.last! }.sorted()).to(equal([0x01, 0x0a]))
                }
            }

            context("error propagation") {
                it("decodeHexBytes wraps invalid hex with the JSON path") {
                    let json = #"""
                    {
                      "bytes": "0xZZ",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex byte string"))
                        })
                }
                it("decodeHexBytesIfPresent surfaces decoder errors when present-but-bad") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "optionalBytes": "0xZZ",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex byte string"))
                        })
                }
                it("decodeHexUInt8 (strict, non-optional) wraps invalid input") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "strictTxType": "0xZZ",
                      "txType": "0x02",
                      "nonce": "0x10",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex UInt8"))
                        })
                }
                it("decodeHexUInt8 rejects too-wide input") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x0100",
                      "nonce": "0x10",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex UInt8"))
                        })
                }
                it("decodeHexUInt8IfPresent surfaces error when present-but-bad") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "absentTxType": "0xZZ",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex UInt8"))
                        })
                }
                it("decodeHexUInt64 rejects too-wide input") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x010000000000000000",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex UInt64"))
                        })
                }
                it("decodeHexUInt64IfPresent surfaces error when present-but-bad") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "optionalNonce": "0x010000000000000000",
                      "datas": [], "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex UInt64"))
                        })
                }
                it("decodeHexBytesArray surfaces a bad element") {
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": ["0xZZ"],
                      "values": [], "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex byte string in array"))
                        })
                }
                it("decodeHexU256Array surfaces a bad element") {
                    let s = "0x" + String(repeating: "ff", count: 33)
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": [],
                      "values": ["\#(s)"],
                      "storage": {}
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid hex U256 in array"))
                        })
                }
                it("decodeStorageMap surfaces a bad key") {
                    let badKey = "0x" + String(repeating: "ab", count: 33)
                    let json = #"""
                    {
                      "bytes": "0x",
                      "txType": "0x02",
                      "strictTxType": "0x03",
                      "nonce": "0x10",
                      "datas": [], "values": [],
                      "storage": { "\#(badKey)": "0x01" }
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(Sample.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid storage entry"))
                        })
                }
            }
        }
    }
}
