@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

private func makeBackend() -> TestBackend {
    let v = Vicinity(
        gasPrice: .ZERO, origin: H160.ZERO, blockHashes: [],
        blockNumber: .ZERO, blockCoinbase: H160.ZERO, blockTimestamp: .ZERO,
        blockDifficulty: .ZERO, blockGasLimit: .ZERO, chainId: .ZERO,
        blockBaseFeePerGas: .ZERO, blockRandomness: nil, blobGasPrice: nil, blobHashes: []
    )
    return TestBackend(vicinity: v, accounts: [:], storage: [:])
}

private func makeCallInput() -> Transactor.Input {
    Transactor.Input(
        spec: .Cancun,
        caller: h160LastByte(0xaa),
        to: h160LastByte(0xbb),
        value: .ZERO,
        data: [],
        gasLimit: 21000,
        accessList: [],
        authorizationList: []
    )
}

private func makeCreateInput() -> Transactor.Input {
    Transactor.Input(
        spec: .Cancun,
        caller: h160LastByte(0xaa),
        to: nil,
        value: .ZERO,
        data: [],
        gasLimit: 21000,
        accessList: [],
        authorizationList: []
    )
}

final class TransactorSpec: QuickSpec {
    override class func spec() {
        describe("Transactor seam") {
            context("call") {
                it("throws notImplemented with a TODO-pointing message") {
                    let backend = makeBackend()
                    expect { try Transactor.call(input: makeCallInput(), backend: backend) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("transact_call"))
                            expect(String(describing: e)).to(contain("Transactor.swift TODO"))
                        })
                }
            }

            context("create") {
                it("throws notImplemented with a TODO-pointing message") {
                    let backend = makeBackend()
                    expect { try Transactor.create(input: makeCreateInput(), backend: backend) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("transact_create"))
                            expect(String(describing: e)).to(contain("Transactor.swift TODO"))
                        })
                }
            }

            context("Authorization value type") {
                it("stores authority/address/nonce/isValid verbatim") {
                    let auth = Authorization(
                        authority: h160LastByte(0x01),
                        address: h160LastByte(0x02),
                        nonce: 7,
                        isValid: true
                    )
                    expect(auth.authority.BYTES.last).to(equal(0x01))
                    expect(auth.address.BYTES.last).to(equal(0x02))
                    expect(auth.nonce).to(equal(7))
                    expect(auth.isValid).to(beTrue())
                }
            }

            context("Output value type") {
                it("packages exitReason / returnData / gasUsed") {
                    let o = Transactor.Output(
                        exitReason: .Revert, returnData: [0xab], gasUsed: 500
                    )
                    if case .Revert = o.exitReason {
                        expect(o.returnData).to(equal([0xab]))
                        expect(o.gasUsed).to(equal(500))
                    } else {
                        fail("expected Revert")
                    }
                }
            }
        }
    }
}
