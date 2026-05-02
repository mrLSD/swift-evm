@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class CallSpec: QuickSpec {
    override class func spec() {
        describe("Call type") {
            let decoder = JSONDecoder()

            it("decodes data/destination/gasLimit/value") {
                let json = #"""
                {
                  "data": "0xabcd",
                  "destination": "0x000000000000000000000000000000000000aaaa",
                  "gasLimit": "0x5208",
                  "value": "0x10"
                }
                """#.data(using: .utf8)!
                let c = try! decoder.decode(Call.self, from: json)
                expect(c.data).to(equal([0xab, 0xcd]))
                expect(c.destination?.BYTES.last).to(equal(0xaa))
                expect(c.gasLimit).to(equal(U256(from: 21000)))
                expect(c.value).to(equal(U256(from: 16)))
            }
            it("treats absent destination as nil") {
                let json = #"""
                { "data": "0x", "gasLimit": "0x0", "value": "0x0" }
                """#.data(using: .utf8)!
                let c = try! decoder.decode(Call.self, from: json)
                expect(c.destination).to(beNil())
            }
        }
    }
}

final class ExecutionTransactionSpec: QuickSpec {
    override class func spec() {
        describe("ExecutionTransaction type") {
            let decoder = JSONDecoder()

            it("decodes all required fields and renames `caller` to `sender`") {
                let json = #"""
                {
                  "address":   "0x0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6",
                  "caller":    "0xcd1722f3947def4cf144679da39c4c32bdc35681",
                  "code":      "0x600260010100",
                  "data":      "0x",
                  "gas":       "0x0f4240",
                  "gasPrice":  "0x01",
                  "origin":    "0xcd1722f3947def4cf144679da39c4c32bdc35681",
                  "value":     "0x00"
                }
                """#.data(using: .utf8)!
                let exec = try! decoder.decode(ExecutionTransaction.self, from: json)
                expect(exec.code).to(equal([0x60, 0x02, 0x60, 0x01, 0x01, 0x00]))
                expect(exec.gas).to(equal(U256(from: 0x0f4240)))
                expect(exec.gasPrice).to(equal(U256(from: 1)))
                expect(exec.codeVersion.isZero).to(beTrue())
            }
            it("decodes an explicit codeVersion when present") {
                let json = #"""
                {
                  "address":  "0x0000000000000000000000000000000000000001",
                  "caller":   "0x0000000000000000000000000000000000000002",
                  "code":     "0x", "data": "0x",
                  "gas":      "0x01", "gasPrice": "0x01",
                  "origin":   "0x0000000000000000000000000000000000000003",
                  "value":    "0x00",
                  "codeVersion": "0x07"
                }
                """#.data(using: .utf8)!
                let exec = try! decoder.decode(ExecutionTransaction.self, from: json)
                expect(exec.codeVersion).to(equal(U256(from: 7)))
            }
            it("defaults codeVersion to ZERO when absent") {
                let json = #"""
                {
                  "address":  "0x0000000000000000000000000000000000000001",
                  "caller":   "0x0000000000000000000000000000000000000002",
                  "code":     "0x", "data": "0x",
                  "gas":      "0x01", "gasPrice": "0x01",
                  "origin":   "0x0000000000000000000000000000000000000003",
                  "value":    "0x00"
                }
                """#.data(using: .utf8)!
                let exec = try! decoder.decode(ExecutionTransaction.self, from: json)
                expect(exec.codeVersion.isZero).to(beTrue())
            }
        }
    }
}

final class VmTestCaseSpec: QuickSpec {
    override class func spec() {
        describe("VmTestCase type") {
            let decoder = JSONDecoder()

            it("decodes a minimal VM test") {
                let json = #"""
                {
                  "callcreates": [],
                  "env": {
                    "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                    "currentDifficulty": "0x100000",
                    "currentGasLimit": "0x0f4240",
                    "currentNumber": "0x00",
                    "currentTimestamp": "0x01"
                  },
                  "exec": {
                    "address": "0x0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6",
                    "caller":  "0xcd1722f3947def4cf144679da39c4c32bdc35681",
                    "code":    "0x600260010100",
                    "data":    "0x",
                    "gas":     "0x0f4240",
                    "gasPrice":"0x01",
                    "origin":  "0xcd1722f3947def4cf144679da39c4c32bdc35681",
                    "value":   "0x00"
                  },
                  "gas":  "0x0f422a",
                  "logs": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
                  "out":  "0x",
                  "pre": {
                    "0x0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6": {
                      "nonce": "0x00", "balance": "0x00",
                      "code": "0x600260010100", "storage": {}
                    }
                  },
                  "post": {
                    "0x0f572e5295c57f15886f9b263e2f6d2d6c7b5ec6": {
                      "nonce": "0x00", "balance": "0x00",
                      "code": "0x600260010100", "storage": {}
                    }
                  }
                }
                """#.data(using: .utf8)!
                let vt = try! decoder.decode(VmTestCase.self, from: json)
                expect(vt.calls?.count).to(equal(0))
                expect(vt.preState.accounts.count).to(equal(1))
                expect(vt.postState).toNot(beNil())
                expect(vt.gasLeft).to(equal(U256(from: 0x0f422a)))
                expect(vt.logs).toNot(beNil())
                expect(vt.output).to(equal([]))
            }
            it("treats absent optional fields as nil") {
                let json = #"""
                {
                  "env": {
                    "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                    "currentDifficulty": "0x0",
                    "currentGasLimit": "0x0",
                    "currentNumber": "0x0",
                    "currentTimestamp": "0x0"
                  },
                  "exec": {
                    "address": "0x0000000000000000000000000000000000000001",
                    "caller":  "0x0000000000000000000000000000000000000002",
                    "code":    "0x", "data": "0x",
                    "gas":     "0x0", "gasPrice": "0x0",
                    "origin":  "0x0000000000000000000000000000000000000003",
                    "value":   "0x0"
                  },
                  "pre": {}
                }
                """#.data(using: .utf8)!
                let vt = try! decoder.decode(VmTestCase.self, from: json)
                expect(vt.calls).to(beNil())
                expect(vt.gasLeft).to(beNil())
                expect(vt.logs).to(beNil())
                expect(vt.output).to(beNil())
                expect(vt.postState).to(beNil())
            }
        }
    }
}
