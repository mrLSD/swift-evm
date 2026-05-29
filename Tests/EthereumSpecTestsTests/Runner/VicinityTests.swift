@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class VicinitySpec: QuickSpec {
    override class func spec() {
        describe("Vicinity type") {
            context("fromStateEnv") {
                it("zeros out tx-level fields and copies block-env fields") {
                    let env = StateEnv(
                        blockDifficulty: U256(from: 1),
                        blockCoinbase: h160LastByte(0xaa),
                        blockGasLimit: U256(from: 1_000_000),
                        blockNumber: U256(from: 7),
                        blockTimestamp: U256(from: 1234),
                        blockBaseFeePerGas: U256(from: 5),
                        random: h256LastByte(0x42),
                        parentBlobGasUsed: nil,
                        parentExcessBlobGas: nil,
                        currentExcessBlobGas: nil
                    )
                    let v = Vicinity.fromStateEnv(env)
                    expect(v.gasPrice.isZero).to(beTrue())
                    expect(v.origin).to(equal(H160.ZERO))
                    expect(v.chainId.isZero).to(beTrue())
                    expect(v.blockNumber).to(equal(U256(from: 7)))
                    expect(v.blockCoinbase.BYTES.last).to(equal(0xaa))
                    expect(v.blockBaseFeePerGas).to(equal(U256(from: 5)))
                    expect(v.blockRandomness?.BYTES.last).to(equal(0x42))
                    expect(v.blockHashes).to(beEmpty())
                    expect(v.blobGasPrice).to(beNil())
                    expect(v.blobHashes).to(beEmpty())
                }
            }

            context("fromVm") {
                it("populates gasPrice/origin/baseFee from the exec block") {
                    let env = StateEnv(
                        blockDifficulty: .ZERO, blockCoinbase: .ZERO, blockGasLimit: .ZERO,
                        blockNumber: U256(from: 1), blockTimestamp: U256(from: 1),
                        blockBaseFeePerGas: .ZERO, random: nil,
                        parentBlobGasUsed: nil, parentExcessBlobGas: nil, currentExcessBlobGas: nil
                    )
                    let exec = ExecutionTransaction(
                        address: h160LastByte(0x01),
                        sender:  h160LastByte(0x02),
                        code: [], data: [],
                        gas: U256(from: 100),
                        gasPrice: U256(from: 11),
                        origin: h160LastByte(0x03),
                        value: .ZERO,
                        codeVersion: .ZERO
                    )
                    let v = Vicinity.fromVm(env: env, exec: exec)
                    expect(v.gasPrice).to(equal(U256(from: 11)))
                    expect(v.origin.BYTES.last).to(equal(0x03))
                    expect(v.blockBaseFeePerGas).to(equal(U256(from: 11)))
                }
            }
        }
    }
}
