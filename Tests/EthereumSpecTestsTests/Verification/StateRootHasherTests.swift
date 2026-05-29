@testable import EthereumSpecTests
import CryptoSwift
import Foundation
import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class StateRootHasherSpec: QuickSpec {
    override class func spec() {
        describe("StateRootHasher type") {
            context("emptyTrieRoot") {
                it("matches the well-known empty Patricia trie hash") {
                    let expected = "56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
                    expect(StateRootHasher.emptyTrieRoot.encodeHexLower()).to(equal(expected))
                }
            }

            context("compute") {
                it("throws notImplemented because the MPT layer is stubbed") {
                    expect { try StateRootHasher.compute(accounts: [:], storage: [:]) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Merkle-Patricia Trie root not implemented"))
                        })
                }
                it("throws even when given non-empty input — the stub is unconditional") {
                    let acc: [H160: (BasicAccount, [UInt8])] = [
                        h160LastByte(0x01): (BasicAccount(balance: .ZERO, nonce: .ZERO), [])
                    ]
                    expect { try StateRootHasher.compute(accounts: acc, storage: [:]) }
                        .to(throwError())
                }
            }

            context("buildTrieAccounts") {
                it("returns an empty array for an empty input") {
                    let result = StateRootHasher.buildTrieAccounts(accounts: [:], storage: [:])
                    expect(result).to(beEmpty())
                }
                it("returns one (address, RLP) entry per account, sorted by address bytes") {
                    let a = h160LastByte(0x03)
                    let b = h160LastByte(0x01)
                    let c = h160LastByte(0x02)
                    let accs: [H160: (BasicAccount, [UInt8])] = [
                        a: (BasicAccount(balance: .ZERO, nonce: .ZERO), []),
                        b: (BasicAccount(balance: .ZERO, nonce: .ZERO), []),
                        c: (BasicAccount(balance: .ZERO, nonce: .ZERO), [])
                    ]
                    let result = StateRootHasher.buildTrieAccounts(accounts: accs, storage: [:])
                    expect(result.map { $0.0.BYTES.last! }).to(equal([0x01, 0x02, 0x03]))
                    for (_, bytes) in result {
                        expect(bytes.first).to(equal(0xf8))
                    }
                }
                it("uses keccak(code) as the codeHash field") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let expected = SHA3(variant: .keccak256).calculate(for: code)

                    let accs: [H160: (BasicAccount, [UInt8])] = [
                        h160LastByte(0x01): (BasicAccount(balance: .ZERO, nonce: .ZERO), code)
                    ]
                    let entries = StateRootHasher.buildTrieAccounts(accounts: accs, storage: [:])
                    let rlp = entries[0].1
                    let codeHashStart = rlp.count - 32
                    let actualCodeHashSlice = Array(rlp[codeHashStart..<rlp.count])
                    expect(actualCodeHashSlice).to(equal(expected))
                }
                it("ignores storage entries for now (stubbed storage root)") {
                    let storage: [H160: [H256: H256]] = [
                        h160LastByte(0x01): [h256LastByte(0x01): h256LastByte(0xaa)]
                    ]
                    let accs: [H160: (BasicAccount, [UInt8])] = [
                        h160LastByte(0x01): (BasicAccount(balance: .ZERO, nonce: .ZERO), [])
                    ]
                    let withStorage = StateRootHasher.buildTrieAccounts(accounts: accs, storage: storage)
                    let withoutStorage = StateRootHasher.buildTrieAccounts(accounts: accs, storage: [:])
                    expect(withStorage.map { $0.1 }).to(equal(withoutStorage.map { $0.1 }))
                }
            }
        }
    }
}
