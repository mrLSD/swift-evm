@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class StateEnvSpec: QuickSpec {
    override class func spec() {
        describe("StateEnv type") {
            let decoder = JSONDecoder()

            it("decodes the required block-env fields") {
                let json = #"""
                {
                  "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                  "currentDifficulty": "0x20000",
                  "currentGasLimit": "0x05f5e100",
                  "currentNumber": "0x01",
                  "currentTimestamp": "0x03e8",
                  "currentBaseFee": "0x07"
                }
                """#.data(using: .utf8)!
                let env = try! decoder.decode(StateEnv.self, from: json)
                expect(env.blockNumber).to(equal(U256(from: 1)))
                expect(env.blockTimestamp).to(equal(U256(from: 1000)))
                expect(env.blockBaseFeePerGas).to(equal(U256(from: 7)))
                expect(env.random).to(beNil())
                expect(env.parentBlobGasUsed).to(beNil())
                expect(env.parentExcessBlobGas).to(beNil())
                expect(env.currentExcessBlobGas).to(beNil())
            }
            it("defaults baseFee to ZERO when missing") {
                let json = #"""
                {
                  "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                  "currentDifficulty": "0x0",
                  "currentGasLimit": "0x0",
                  "currentNumber": "0x0",
                  "currentTimestamp": "0x0"
                }
                """#.data(using: .utf8)!
                let env = try! decoder.decode(StateEnv.self, from: json)
                expect(env.blockBaseFeePerGas.isZero).to(beTrue())
            }
            it("decodes optional EIP-4844 / random fields") {
                let json = #"""
                {
                  "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                  "currentDifficulty": "0x0",
                  "currentGasLimit": "0x0",
                  "currentNumber": "0x0",
                  "currentTimestamp": "0x0",
                  "currentRandom": "0x42",
                  "parentBlobGasUsed": "0x10",
                  "parentExcessBlobGas": "0x20",
                  "currentExcessBlobGas": "0x30"
                }
                """#.data(using: .utf8)!
                let env = try! decoder.decode(StateEnv.self, from: json)
                expect(env.random?.BYTES.last).to(equal(0x42))
                expect(env.parentBlobGasUsed).to(equal(0x10))
                expect(env.parentExcessBlobGas).to(equal(0x20))
                expect(env.currentExcessBlobGas).to(equal(0x30))
            }
        }
    }
}

final class PreStateSpec: QuickSpec {
    override class func spec() {
        describe("PreState type") {
            let decoder = JSONDecoder()

            it("wraps an AccountsState directly") {
                let json = #"""
                {
                  "0x000000000000000000000000000000000000aaaa": {
                    "nonce": "0x00", "balance": "0x10", "code": "0x", "storage": {}
                  }
                }
                """#.data(using: .utf8)!
                let pre = try! decoder.decode(PreState.self, from: json)
                expect(pre.accounts.accounts.count).to(equal(1))
            }
        }
    }
}

final class PostStateIndexesSpec: QuickSpec {
    override class func spec() {
        describe("PostStateIndexes type") {
            let decoder = JSONDecoder()

            it("decodes data/gas/value triple") {
                let json = #"{ "data": 1, "gas": 2, "value": 3 }"#.data(using: .utf8)!
                let idx = try! decoder.decode(PostStateIndexes.self, from: json)
                expect(idx.data).to(equal(1))
                expect(idx.gas).to(equal(2))
                expect(idx.value).to(equal(3))
            }
        }
    }
}

final class PostStateSpec: QuickSpec {
    override class func spec() {
        describe("PostState type") {
            let decoder = JSONDecoder()

            it("decodes hash + logs + indexes + txbytes") {
                let json = #"""
                {
                  "hash": "0x0011223344556677889900112233445566778899001122334455667788990011",
                  "logs": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                  "indexes": { "data": 0, "gas": 0, "value": 0 },
                  "txbytes": "0xf86f"
                }
                """#.data(using: .utf8)!
                let p = try! decoder.decode(PostState.self, from: json)
                expect(p.hash.BYTES.last).to(equal(0x11))
                expect(p.txBytes).to(equal([0xf8, 0x6f]))
                expect(p.expectException).to(beNil())
                expect(p.state).to(beNil())
                expect(p.postState).to(beNil())
            }
            it("decodes optional expectException") {
                let json = #"""
                {
                  "hash": "0x0011223344556677889900112233445566778899001122334455667788990011",
                  "logs": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                  "indexes": { "data": 0, "gas": 0, "value": 0 },
                  "txbytes": "0xf86f",
                  "expectException": "TR_NoFunds"
                }
                """#.data(using: .utf8)!
                let p = try! decoder.decode(PostState.self, from: json)
                expect(p.expectException).to(equal("TR_NoFunds"))
            }
        }
    }
}

final class StateTestCaseSpec: QuickSpec {
    override class func spec() {
        describe("StateTestCase type") {
            let decoder = JSONDecoder()

            it("decodes a minimal end-to-end state test") {
                let json = #"""
                {
                  "env": {
                    "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                    "currentDifficulty": "0x20000",
                    "currentGasLimit": "0x05f5e100",
                    "currentNumber": "0x01",
                    "currentTimestamp": "0x03e8",
                    "currentBaseFee": "0x07"
                  },
                  "pre": {
                    "0x000000000000000000000000000000000000aaaa": {
                      "nonce": "0x0", "balance": "0x0de0b6b3a7640000",
                      "code": "0x600160005500", "storage": {}
                    }
                  },
                  "post": {
                    "Cancun": [
                      {
                        "hash": "0x0011223344556677889900112233445566778899001122334455667788990011",
                        "logs": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                        "indexes": {"data": 0, "gas": 0, "value": 0},
                        "txbytes": "0xf86f"
                      }
                    ]
                  },
                  "transaction": {
                    "data": ["0x"],
                    "gasLimit": ["0x05f5e100"],
                    "gasPrice": "0x0a",
                    "nonce": "0x0",
                    "to": "0x000000000000000000000000000000000000aaaa",
                    "value": ["0x00"]
                  },
                  "out": "0x",
                  "_info": { "source": "test" }
                }
                """#.data(using: .utf8)!
                let tc = try! decoder.decode(StateTestCase.self, from: json)
                expect(tc.preState.accounts.accounts.count).to(equal(1))
                expect(tc.postStates.count).to(equal(1))
                expect(tc.postStates[.Cancun]?.count).to(equal(1))
                expect(tc.transaction.gasLimit.first).to(equal(U256(from: 100_000_000)))
                expect(tc.out).to(equal([]))
                expect(tc.info?.source).to(equal("test"))
            }
            it("rejects an unknown spec name in `post`") {
                let json = #"""
                {
                  "env": {
                    "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                    "currentDifficulty": "0x0",
                    "currentGasLimit": "0x0",
                    "currentNumber": "0x0",
                    "currentTimestamp": "0x0"
                  },
                  "pre": {},
                  "post": { "NotAFork": [] },
                  "transaction": {
                    "data": ["0x"], "gasLimit": ["0x0"], "gasPrice": "0x0",
                    "nonce": "0x0", "value": ["0x0"]
                  }
                }
                """#.data(using: .utf8)!
                expect { try decoder.decode(StateTestCase.self, from: json) }
                    .to(throwError { (e: Error) in
                        expect(String(describing: e)).to(contain("Unknown Spec key in postStates"))
                    })
            }
        }
    }
}

final class InvalidTxReasonSpec: QuickSpec {
    override class func spec() {
        describe("InvalidTxReason type") {
            it("supports Equatable") {
                expect(InvalidTxReason.outOfFund).to(equal(InvalidTxReason.outOfFund))
                expect(InvalidTxReason.outOfFund).toNot(equal(InvalidTxReason.intrinsicGas))
            }
        }
    }
}
