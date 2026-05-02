@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import PrimitiveTypes
import Quick

private let addrA = h160LastByte(0xa1)
private let addrB = h160LastByte(0xa2)
private let key1 = h256LastByte(0x01)
private let val1 = h256LastByte(0xff)

private func makeBackend(
    blobGasPrice: U128? = nil,
    blobHashes: [U256] = [],
    blockHashes: [H256] = []
) -> TestBackend {
    let v = Vicinity(
        gasPrice: U256(from: 7),
        origin: addrA,
        blockHashes: blockHashes,
        blockNumber: U256(from: 100),
        blockCoinbase: addrB,
        blockTimestamp: U256(from: 200),
        blockDifficulty: U256(from: 1234),
        blockGasLimit: U256(from: 500_000),
        chainId: U256(from: 1),
        blockBaseFeePerGas: U256(from: 9),
        blockRandomness: h256LastByte(0xaa),
        blobGasPrice: blobGasPrice,
        blobHashes: blobHashes
    )
    let accs: [H160: (BasicAccount, [UInt8])] = [
        addrA: (BasicAccount(balance: U256(from: 99), nonce: U256(from: 1)), [0x60, 0x00])
    ]
    let storage: [H160: [H256: H256]] = [addrA: [key1: val1]]
    return TestBackend(vicinity: v, accounts: accs, storage: storage)
}

final class TestBackendSpec: QuickSpec {
    override class func spec() {
        describe("TestBackend type") {
            context("block-environment fields") {
                it("returns the expected gasPrice / origin / chainId") {
                    let b = makeBackend()
                    expect(b.gasPrice()).to(equal(U256(from: 7)))
                    expect(b.origin()).to(equal(addrA))
                    expect(b.chainId()).to(equal(U256(from: 1)))
                }
                it("returns the expected block-info values") {
                    let b = makeBackend()
                    expect(b.blockNumber()).to(equal(U256(from: 100)))
                    expect(b.blockTimestamp()).to(equal(U256(from: 200)))
                    expect(b.blockDifficulty()).to(equal(U256(from: 1234)))
                    expect(b.blockGasLimit()).to(equal(U256(from: 500_000)))
                    expect(b.blockBaseFeePerGas()).to(equal(U256(from: 9)))
                    expect(b.blockCoinbase()).to(equal(addrB))
                    expect(b.blockRandomness()?.BYTES.last).to(equal(0xaa))
                }
            }

            context("blockHash") {
                it("returns ZERO for an out-of-range index") {
                    let b = makeBackend(blockHashes: [])
                    expect(b.blockHash(number: U256(from: 0))).to(equal(H256.ZERO))
                    expect(b.blockHash(number: U256(from: 99))).to(equal(H256.ZERO))
                }
                it("returns the indexed hash when in range") {
                    let h = h256LastByte(0xbe)
                    let b = makeBackend(blockHashes: [h])
                    expect(b.blockHash(number: U256(from: 0))).to(equal(h))
                }
            }

            context("account-state queries") {
                it("exists() returns true only for known addresses") {
                    let b = makeBackend()
                    expect(b.exists(address: addrA)).to(beTrue())
                    expect(b.exists(address: addrB)).to(beFalse())
                }
                it("basic() returns the populated account, or default ZERO/ZERO for unknown") {
                    let b = makeBackend()
                    let acc = b.basic(address: addrA)
                    expect(acc.balance).to(equal(U256(from: 99)))
                    expect(acc.nonce).to(equal(U256(from: 1)))

                    let zero = b.basic(address: addrB)
                    expect(zero.balance.isZero).to(beTrue())
                    expect(zero.nonce.isZero).to(beTrue())
                }
                it("code() returns the code or [] for unknown addresses") {
                    let b = makeBackend()
                    expect(b.code(address: addrA)).to(equal([0x60, 0x00]))
                    expect(b.code(address: addrB)).to(equal([]))
                }
                it("storage() returns ZERO for missing slots and the value otherwise") {
                    let b = makeBackend()
                    expect(b.storage(address: addrA, index: key1)).to(equal(val1))
                    expect(b.storage(address: addrA, index: h256LastByte(0x99))).to(equal(H256.ZERO))
                    expect(b.storage(address: addrB, index: key1)).to(equal(H256.ZERO))
                }
                it("isEmptyStorage() detects empty storage maps") {
                    let b = makeBackend()
                    expect(b.isEmptyStorage(address: addrA)).to(beFalse())
                    expect(b.isEmptyStorage(address: addrB)).to(beTrue())
                }
                it("originalStorage() mirrors storage() for the test runner") {
                    let b = makeBackend()
                    expect(b.originalStorage(address: addrA, index: key1)).to(equal(val1))
                    expect(b.originalStorage(address: addrA, index: h256LastByte(0x99))).to(beNil())
                }
            }

            context("EIP-4844 blob accessors") {
                it("blobGasPrice() returns ZERO when vicinity has none") {
                    expect(makeBackend(blobGasPrice: nil).blobGasPrice()).to(equal(U128.ZERO))
                }
                it("blobGasPrice() returns the configured value") {
                    let b = makeBackend(blobGasPrice: U128(from: 42))
                    expect(b.blobGasPrice()).to(equal(U128(from: 42)))
                }
                it("getBlobHash() returns nil for OOB indices and the value otherwise") {
                    let h0 = U256(from: 0xcafe)
                    let b = makeBackend(blobHashes: [h0])
                    expect(b.getBlobHash(index: 0)).to(equal(h0))
                    expect(b.getBlobHash(index: 1)).to(beNil())
                }
            }
        }
    }
}
