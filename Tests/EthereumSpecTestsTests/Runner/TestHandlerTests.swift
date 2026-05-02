@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class TestHandlerSpec: QuickSpec {
    override class func spec() {
        describe("TestHandler type") {
            let addrA = h160LastByte(0xa1)
            let addrB = h160LastByte(0xa2)

            func makeHandler() -> (TestHandler, TestBackend) {
                let v = Vicinity(
                    gasPrice: U256(from: 11),
                    origin: addrA,
                    blockHashes: [],
                    blockNumber: .ZERO,
                    blockCoinbase: addrB,
                    blockTimestamp: .ZERO,
                    blockDifficulty: .ZERO,
                    blockGasLimit: .ZERO,
                    chainId: U256(from: 33),
                    blockBaseFeePerGas: .ZERO,
                    blockRandomness: nil,
                    blobGasPrice: nil,
                    blobHashes: []
                )
                let accs: [H160: (BasicAccount, [UInt8])] = [
                    addrA: (BasicAccount(balance: U256(from: 100), nonce: .ZERO), [])
                ]
                let backend = TestBackend(vicinity: v, accounts: accs, storage: [:])
                return (TestHandler(backend: backend), backend)
            }

            it("returns nil from beforeOpcodeExecution (no inject hooks today)") {
                let (h, _) = makeHandler()
                let m = Machine(
                    callData: [], code: [],
                    gasLimit: 100, memoryLimit: 1024,
                    targetAddress: H160.ZERO, callerAddress: H160.ZERO, callValue: .ZERO,
                    handler: h, hardFork: .Prague
                )
                expect(h.beforeOpcodeExecution(machine: m, opcode: nil)).to(beNil())
            }
            it("delegates env queries to the backend") {
                let (h, _) = makeHandler()
                expect(h.balance(address: addrA)).to(equal(U256(from: 100)))
                expect(h.balance(address: addrB)).to(equal(U256.ZERO))
                expect(h.gasPrice()).to(equal(U256(from: 11)))
                expect(h.origin()).to(equal(addrA))
                expect(h.chainId()).to(equal(U256(from: 33)))
                expect(h.coinbase()).to(equal(addrB))
            }
        }
    }
}
