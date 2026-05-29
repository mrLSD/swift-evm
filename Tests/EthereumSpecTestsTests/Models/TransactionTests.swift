@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class AccessListTupleSpec: QuickSpec {
    override class func spec() {
        describe("AccessListTuple type") {
            let decoder = JSONDecoder()

            it("decodes address + storageKeys") {
                let json = #"""
                {
                  "address": "0x000000000000000000000000000000000000000a",
                  "storageKeys": ["0x01", "0x02"]
                }
                """#.data(using: .utf8)!
                let t = try! decoder.decode(AccessListTuple.self, from: json)
                expect(t.address.BYTES.last).to(equal(0x0a))
                expect(t.storageKeys.count).to(equal(2))
            }
        }
    }
}

final class TxTypeSpec: QuickSpec {
    override class func spec() {
        describe("TxType type") {
            context("from(txBytes:)") {
                it("classifies legacy by leading byte > 0x7f") {
                    expect(TxType.from(txBytes: [0xf8, 0x00])).to(equal(TxType.legacy))
                    expect(TxType.from(txBytes: [0x80])).to(equal(TxType.legacy))
                }
                it("classifies type bytes 1-4") {
                    expect(TxType.from(txBytes: [1])).to(equal(TxType.accessList))
                    expect(TxType.from(txBytes: [2])).to(equal(TxType.dynamicFee))
                    expect(TxType.from(txBytes: [3])).to(equal(TxType.shardBlob))
                    expect(TxType.from(txBytes: [4])).to(equal(TxType.eoaAccountCode))
                }
                it("returns nil for unknown low bytes") {
                    expect(TxType.from(txBytes: [0])).to(beNil())
                    expect(TxType.from(txBytes: [5])).to(beNil())
                    expect(TxType.from(txBytes: [0x7f])).to(beNil())
                }
                it("returns nil for empty input") {
                    expect(TxType.from(txBytes: [])).to(beNil())
                }
            }
        }
    }
}

final class TransactionSpec: QuickSpec {
    override class func spec() {
        describe("Transaction type") {
            let decoder = JSONDecoder()

            context("Decodable") {
                it("decodes a typed-1559 transaction with multiple data/gas/value variants") {
                    let json = #"""
                    {
                      "type": "0x02",
                      "data": ["0x", "0xabcd"],
                      "gasLimit": ["0x186a0", "0x5208"],
                      "nonce": "0x0",
                      "to": "0x000000000000000000000000000000000000000a",
                      "value": ["0x0", "0x10"],
                      "maxFeePerGas": "0x100",
                      "maxPriorityFeePerGas": "0x1",
                      "secretKey": "0x45a915e4d060149eb4365960e6a7a45f334393093061116b197e3240065ff2d8",
                      "sender": "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
                      "accessLists": [
                        null,
                        [{"address": "0x000000000000000000000000000000000000000a", "storageKeys": ["0x01"]}]
                      ]
                    }
                    """#.data(using: .utf8)!
                    let tx = try! decoder.decode(Transaction.self, from: json)
                    expect(tx.txType).to(equal(2))
                    expect(tx.data).to(equal([[], [0xab, 0xcd]]))
                    expect(tx.gasLimit.count).to(equal(2))
                    expect(tx.value[1]).to(equal(U256(from: 16)))
                    expect(tx.maxFeePerGas).to(equal(U256(from: 256)))
                    expect(tx.accessLists.count).to(equal(2))
                    expect(tx.accessLists[0]).to(beNil())
                    expect(tx.accessLists[1]).toNot(beNil())
                    expect(tx.sender?.BYTES.last).to(equal(0x0b))
                }
                it("treats absent accessLists/blobs/auth as empty defaults") {
                    let json = #"""
                    {
                      "data": ["0x"],
                      "gasLimit": ["0x5208"],
                      "gasPrice": "0x1",
                      "nonce": "0x0",
                      "value": ["0x0"]
                    }
                    """#.data(using: .utf8)!
                    let tx = try! decoder.decode(Transaction.self, from: json)
                    expect(tx.accessLists).to(beEmpty())
                    expect(tx.blobVersionedHashes).to(beEmpty())
                    expect(tx.authorizationList).to(beNil())
                    expect(tx.txType).to(beNil())
                    expect(tx.gasPrice).to(equal(U256(from: 1)))
                    expect(tx.to).to(beNil())
                }
                it("decodes blob and authorization fields when present") {
                    let json = #"""
                    {
                      "type": "0x03",
                      "data": ["0x"],
                      "gasLimit": ["0x5208"],
                      "nonce": "0x0",
                      "value": ["0x0"],
                      "maxFeePerGas": "0x1",
                      "maxPriorityFeePerGas": "0x1",
                      "maxFeePerBlobGas": "0x05",
                      "blobVersionedHashes": ["0x01", "0x02"],
                      "initcodes": "0x6000",
                      "authorizationList": [
                        {
                          "chainId": "0x01", "address": "0x000000000000000000000000000000000000aaaa",
                          "nonce": "0x0", "r": "0x1", "s": "0x2", "v": "0x0"
                        }
                      ]
                    }
                    """#.data(using: .utf8)!
                    let tx = try! decoder.decode(Transaction.self, from: json)
                    expect(tx.blobVersionedHashes.count).to(equal(2))
                    expect(tx.maxFeePerBlobGas).to(equal(U256(from: 5)))
                    expect(tx.initCodes).to(equal([0x60, 0x00]))
                    expect(tx.authorizationList?.count).to(equal(1))
                }
            }

            context("variant getters") {
                let baseTx = makeTx()

                it("getData picks by indexes.data") {
                    expect(baseTx.getData(at: PostStateIndexes(data: 0, gas: 0, value: 0))).to(equal([]))
                    expect(baseTx.getData(at: PostStateIndexes(data: 1, gas: 0, value: 0))).to(equal([0xab, 0xcd]))
                }
                it("getGasLimit picks by indexes.gas") {
                    expect(baseTx.getGasLimit(at: PostStateIndexes(data: 0, gas: 1, value: 0))).to(equal(U256(from: 21000)))
                }
                it("getValue picks by indexes.value") {
                    expect(baseTx.getValue(at: PostStateIndexes(data: 0, gas: 0, value: 1))).to(equal(U256(from: 16)))
                }
                it("getAccessList resolves the variant's tuples") {
                    let acl = baseTx.getAccessList(at: PostStateIndexes(data: 1, gas: 0, value: 0))
                    expect(acl.count).to(equal(1))
                    expect(acl[0].0.BYTES.last).to(equal(0x0a))
                }
                it("getAccessList returns [] when indexes.data ≥ accessLists.count") {
                    let tx = makeTx(accessLists: [])
                    expect(tx.getAccessList(at: PostStateIndexes(data: 0, gas: 0, value: 0)).count).to(equal(0))
                }
                it("getAccessList returns [] when the variant slot is nil") {
                    let acl = baseTx.getAccessList(at: PostStateIndexes(data: 0, gas: 0, value: 0))
                    expect(acl.count).to(equal(0))
                }
            }
        }

        // Build a Transaction with exactly the structure the variant-getter tests expect.
        func makeTx(accessLists: [AccessList?]? = nil) -> Transaction {
            let aclDefault: [AccessList?] = [
                nil,
                [AccessListTuple(address: h160LastByte(0x0a), storageKeys: [h256LastByte(0x01)])]
            ]
            let json = #"""
            {
              "data": ["0x", "0xabcd"],
              "gasLimit": ["0x186a0", "0x5208"],
              "gasPrice": "0x1",
              "nonce": "0x0",
              "value": ["0x0", "0x10"]
            }
            """#.data(using: .utf8)!
            let decoded = try! JSONDecoder().decode(Transaction.self, from: json)
            // Replace accessLists field via a fresh value (Transaction has let fields, so re-decode with override).
            return Transaction(
                txType: decoded.txType,
                data: decoded.data,
                gasLimit: decoded.gasLimit,
                gasPrice: decoded.gasPrice,
                nonce: decoded.nonce,
                secretKey: decoded.secretKey,
                sender: decoded.sender,
                to: decoded.to,
                value: decoded.value,
                maxFeePerGas: decoded.maxFeePerGas,
                maxPriorityFeePerGas: decoded.maxPriorityFeePerGas,
                initCodes: decoded.initCodes,
                accessLists: accessLists ?? aclDefault,
                blobVersionedHashes: decoded.blobVersionedHashes,
                maxFeePerBlobGas: decoded.maxFeePerBlobGas,
                authorizationList: decoded.authorizationList
            )
        }
    }
}
