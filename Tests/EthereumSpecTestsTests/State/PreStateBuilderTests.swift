@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class PreStateBuilderSpec: QuickSpec {
    override class func spec() {
        describe("PreStateBuilder type") {
            context("build") {
                it("returns empty maps for an empty AccountsState") {
                    let (acc, st) = PreStateBuilder.build(AccountsState([:]))
                    expect(acc).to(beEmpty())
                    expect(st).to(beEmpty())
                }

                it("converts each account into the runtime (BasicAccount, code) tuple") {
                    let addr = h160LastByte(0xaa)
                    let stateAcc = StateAccount(
                        nonce: U256(from: 7),
                        balance: U256(from: 42),
                        code: [0x60, 0x00],
                        storage: [:]
                    )
                    let (acc, _) = PreStateBuilder.build(AccountsState([addr: stateAcc]))
                    let (basic, code) = acc[addr]!
                    expect(basic.balance).to(equal(U256(from: 42)))
                    expect(basic.nonce).to(equal(U256(from: 7)))
                    expect(code).to(equal([0x60, 0x00]))
                }

                it("treats absent code as []") {
                    let addr = h160LastByte(0xaa)
                    let stateAcc = StateAccount(
                        nonce: .ZERO, balance: .ZERO, code: nil, storage: [:]
                    )
                    let (acc, _) = PreStateBuilder.build(AccountsState([addr: stateAcc]))
                    expect(acc[addr]?.1).to(equal([]))
                }

                it("filters out zero-value storage entries") {
                    let addr = h160LastByte(0xaa)
                    let stateAcc = StateAccount(
                        nonce: .ZERO, balance: .ZERO, code: nil,
                        storage: [
                            h256LastByte(0x01): h256LastByte(0xff),
                            h256LastByte(0x02): H256.ZERO,    // dropped
                            h256LastByte(0x03): h256LastByte(0xab)
                        ]
                    )
                    let (_, st) = PreStateBuilder.build(AccountsState([addr: stateAcc]))
                    expect(st[addr]?.count).to(equal(2))
                    expect(st[addr]?[h256LastByte(0x02)]).to(beNil())
                    expect(st[addr]?[h256LastByte(0x01)]).to(equal(h256LastByte(0xff)))
                }

                it("omits the storage entry entirely when all its slots are zero") {
                    let addr = h160LastByte(0xaa)
                    let stateAcc = StateAccount(
                        nonce: .ZERO, balance: .ZERO, code: nil,
                        storage: [h256LastByte(0x01): H256.ZERO]
                    )
                    let (acc, st) = PreStateBuilder.build(AccountsState([addr: stateAcc]))
                    expect(acc[addr]).toNot(beNil())
                    expect(st[addr]).to(beNil())
                }

                it("handles multiple accounts independently") {
                    let a = h160LastByte(0xa1)
                    let b = h160LastByte(0xa2)
                    let s = AccountsState([
                        a: StateAccount(nonce: U256(from: 1), balance: U256(from: 100), code: nil, storage: [:]),
                        b: StateAccount(nonce: U256(from: 2), balance: U256(from: 200), code: [0x01], storage: [
                            h256LastByte(0x01): h256LastByte(0x02)
                        ])
                    ])
                    let (acc, st) = PreStateBuilder.build(s)
                    expect(acc.count).to(equal(2))
                    expect(acc[a]?.0.balance).to(equal(U256(from: 100)))
                    expect(acc[b]?.1).to(equal([0x01]))
                    expect(st[b]?.count).to(equal(1))
                    expect(st[a]).to(beNil())
                }
            }
        }
    }
}
