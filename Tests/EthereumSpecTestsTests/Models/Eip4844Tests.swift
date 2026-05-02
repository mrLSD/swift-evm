@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class Eip4844Spec: QuickSpec {
    override class func spec() {
        describe("Eip4844 helpers") {
            context("constants") {
                it("matches the canonical EIP-4844 / EIP-7691 values") {
                    expect(Eip4844.GAS_PER_BLOB).to(equal(1 << 17))
                    expect(Eip4844.MAX_BLOBS_PER_BLOCK_CANCUN).to(equal(6))
                    expect(Eip4844.MAX_BLOBS_PER_BLOCK_ELECTRA).to(equal(9))
                    expect(Eip4844.TARGET_BLOB_GAS_PER_BLOCK).to(equal(786_432))
                    expect(Eip4844.MIN_BLOB_GASPRICE).to(equal(1))
                    expect(Eip4844.BLOB_GASPRICE_UPDATE_FRACTION).to(equal(3_338_477))
                    expect(Eip4844.VERSIONED_HASH_VERSION_KZG).to(equal(0x01))
                }
            }

            context("calcExcessBlobGas") {
                it("returns zero when (parent_excess + parent_used) is below the target") {
                    expect(Eip4844.calcExcessBlobGas(parentExcessBlobGas: 0, parentBlobGasUsed: 0)).to(equal(0))
                    expect(Eip4844.calcExcessBlobGas(parentExcessBlobGas: 100, parentBlobGasUsed: 200)).to(equal(0))
                }
                it("returns the saturating-subtracted excess otherwise") {
                    let target = Eip4844.TARGET_BLOB_GAS_PER_BLOCK
                    expect(Eip4844.calcExcessBlobGas(parentExcessBlobGas: 0, parentBlobGasUsed: target + 100))
                        .to(equal(100))
                    expect(Eip4844.calcExcessBlobGas(parentExcessBlobGas: target, parentBlobGasUsed: target))
                        .to(equal(target))
                }
            }

            context("calcBlobGasPrice") {
                it("returns MIN_BLOB_GASPRICE when excess is zero") {
                    expect(Eip4844.calcBlobGasPrice(excessBlobGas: 0))
                        .to(equal(U128(from: Eip4844.MIN_BLOB_GASPRICE)))
                }
                it("grows monotonically with excess gas") {
                    let p0 = Eip4844.calcBlobGasPrice(excessBlobGas: 1_000_000)
                    let p1 = Eip4844.calcBlobGasPrice(excessBlobGas: 2_000_000)
                    expect(p1 >= p0).to(beTrue())
                }
            }

            context("getTotalBlobGas") {
                it("multiplies blob count by GAS_PER_BLOB") {
                    expect(Eip4844.getTotalBlobGas(blobHashesLen: 0)).to(equal(0))
                    expect(Eip4844.getTotalBlobGas(blobHashesLen: 3))
                        .to(equal(3 * Eip4844.GAS_PER_BLOB))
                }
            }
        }

        describe("BlobExcessGasAndPrice type") {
            it("computes blob_gas_price from excess via calcBlobGasPrice") {
                let b = BlobExcessGasAndPrice(excessBlobGas: 0)
                expect(b.excessBlobGas).to(equal(0))
                expect(b.blobGasPrice).to(equal(U128(from: Eip4844.MIN_BLOB_GASPRICE)))
            }

            it("derives via fromParent using saturating excess subtraction") {
                let bp = BlobExcessGasAndPrice.fromParent(parentExcessBlobGas: 0, parentBlobGasUsed: 0)
                expect(bp.excessBlobGas).to(equal(0))
            }

            context("fromEnv") {
                it("prefers currentExcessBlobGas when set") {
                    let env = makeStateEnv(currentExcessBlobGas: 1234)
                    let bp = BlobExcessGasAndPrice.fromEnv(env)
                    expect(bp?.excessBlobGas).to(equal(1234))
                }
                it("falls back to parent fields when current is missing") {
                    let env = makeStateEnv(parentBlobGasUsed: 100, parentExcessBlobGas: 50)
                    let bp = BlobExcessGasAndPrice.fromEnv(env)
                    expect(bp?.excessBlobGas)
                        .to(equal(Eip4844.calcExcessBlobGas(parentExcessBlobGas: 50, parentBlobGasUsed: 100)))
                }
                it("returns nil when neither current nor parent fields are present") {
                    expect(BlobExcessGasAndPrice.fromEnv(makeStateEnv())).to(beNil())
                }
                it("returns nil when only one of the parent fields is present") {
                    let env = makeStateEnv(parentBlobGasUsed: 100, parentExcessBlobGas: nil)
                    expect(BlobExcessGasAndPrice.fromEnv(env)).to(beNil())
                }
            }
        }

        describe("Eip4844.fakeExponential preconditions") {
            it("crashes when denominator is zero") {
                expect(captureStandardError {
                    expect {
                        _ = Eip4844.fakeExponential(factor: 1, numerator: 1, denominator: 0)
                    }.to(throwAssertion())
                }).to(contain("denominator must not be zero"))
            }
        }
    }
}

private func makeStateEnv(
    currentExcessBlobGas: UInt64? = nil,
    parentBlobGasUsed: UInt64? = nil,
    parentExcessBlobGas: UInt64? = nil
) -> StateEnv {
    return StateEnv(
        blockDifficulty: .ZERO,
        blockCoinbase: .ZERO,
        blockGasLimit: .ZERO,
        blockNumber: .ZERO,
        blockTimestamp: .ZERO,
        blockBaseFeePerGas: .ZERO,
        random: nil,
        parentBlobGasUsed: parentBlobGasUsed,
        parentExcessBlobGas: parentExcessBlobGas,
        currentExcessBlobGas: currentExcessBlobGas
    )
}
