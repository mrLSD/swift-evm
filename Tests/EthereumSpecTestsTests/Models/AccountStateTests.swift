@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class StateAccountSpec: QuickSpec {
    override class func spec() {
        describe("StateAccount type") {
            let decoder = JSONDecoder()

            context("Decodable") {
                it("decodes all fields including storage") {
                    let json = #"""
                    {
                      "nonce": "0x01",
                      "balance": "0xde0b6b3a7640000",
                      "code": "0x6000",
                      "storage": { "0x00": "0x01", "0x01": "0xff" }
                    }
                    """#.data(using: .utf8)!
                    let acc = try! decoder.decode(StateAccount.self, from: json)
                    expect(acc.nonce).to(equal(U256(from: 1)))
                    expect(acc.code).to(equal([0x60, 0x00]))
                    expect(acc.storage.count).to(equal(2))
                }
                it("treats missing storage as empty") {
                    let json = #"{ "nonce": "0x0", "balance": "0x0" }"#.data(using: .utf8)!
                    let acc = try! decoder.decode(StateAccount.self, from: json)
                    expect(acc.storage).to(beEmpty())
                    expect(acc.code).to(beNil())
                }
                it("treats missing code as nil (not empty array)") {
                    let json = #"{ "nonce": "0x0", "balance": "0x0", "storage": {} }"#.data(using: .utf8)!
                    let acc = try! decoder.decode(StateAccount.self, from: json)
                    expect(acc.code).to(beNil())
                }
                it("decodes empty 0x code as []") {
                    let json = #"{ "nonce": "0x0", "balance": "0x0", "code": "0x", "storage": {} }"#.data(using: .utf8)!
                    let acc = try! decoder.decode(StateAccount.self, from: json)
                    expect(acc.code).to(equal([]))
                }
            }

            context("Equatable") {
                it("compares equal for identical fields") {
                    let a = StateAccount(nonce: .ZERO, balance: .ZERO, code: nil, storage: [:])
                    let b = StateAccount(nonce: .ZERO, balance: .ZERO, code: nil, storage: [:])
                    expect(a).to(equal(b))
                }
                it("compares unequal when nonce differs") {
                    let a = StateAccount(nonce: .ZERO, balance: .ZERO, code: nil, storage: [:])
                    let b = StateAccount(nonce: U256(from: 1), balance: .ZERO, code: nil, storage: [:])
                    expect(a).toNot(equal(b))
                }
            }
        }
    }
}

final class AccountsStateSpec: QuickSpec {
    override class func spec() {
        describe("AccountsState type") {
            let decoder = JSONDecoder()

            context("Decodable") {
                it("maps top-level address keys to H160") {
                    let json = #"""
                    {
                      "0x000000000000000000000000000000000000abcd": {
                        "nonce": "0x02", "balance": "0x10", "code": "0x", "storage": {}
                      }
                    }
                    """#.data(using: .utf8)!
                    let s = try! decoder.decode(AccountsState.self, from: json)
                    expect(s.accounts.count).to(equal(1))
                    let key = s.accounts.keys.first!
                    expect(key.BYTES.last).to(equal(0xcd))
                }
                it("propagates an error when an address key is invalid") {
                    let badKey = "0x" + String(repeating: "ab", count: 21)
                    let json = #"""
                    {
                      "\#(badKey)": { "nonce": "0x0", "balance": "0x0" }
                    }
                    """#.data(using: .utf8)!
                    expect { try decoder.decode(AccountsState.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Invalid AccountsState address key"))
                        })
                }
                it("decodes an empty map") {
                    let json = "{}".data(using: .utf8)!
                    let s = try! decoder.decode(AccountsState.self, from: json)
                    expect(s.accounts).to(beEmpty())
                }
            }

            context("init") {
                it("constructs from a dictionary") {
                    let acc = StateAccount(nonce: .ZERO, balance: .ZERO, code: nil, storage: [:])
                    let s = AccountsState([h160LastByte(0x01): acc])
                    expect(s.accounts.count).to(equal(1))
                }
            }
        }
    }
}

final class TrieAccountSpec: QuickSpec {
    override class func spec() {
        describe("TrieAccount type") {
            it("stores all five fields verbatim") {
                let acc = TrieAccount(
                    nonce: U256(from: 7),
                    balance: U256(from: 99),
                    storageRoot: h256LastByte(0x01),
                    codeHash: h256LastByte(0x02),
                    codeVersion: U256(from: 1)
                )
                expect(acc.nonce).to(equal(U256(from: 7)))
                expect(acc.balance).to(equal(U256(from: 99)))
                expect(acc.storageRoot).to(equal(h256LastByte(0x01)))
                expect(acc.codeHash).to(equal(h256LastByte(0x02)))
                expect(acc.codeVersion).to(equal(U256(from: 1)))
            }
            it("conforms to Equatable") {
                let a = TrieAccount(nonce: .ZERO, balance: .ZERO, storageRoot: .ZERO, codeHash: .ZERO, codeVersion: .ZERO)
                let b = TrieAccount(nonce: .ZERO, balance: .ZERO, storageRoot: .ZERO, codeHash: .ZERO, codeVersion: .ZERO)
                expect(a).to(equal(b))
            }
        }
    }
}
