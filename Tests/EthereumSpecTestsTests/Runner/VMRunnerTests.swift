@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class VMRunnerSpec: QuickSpec {
    override class func spec() {
        describe("VMRunner.run") {
            let silent = VerboseOutput(verbose: false, verboseFailed: false, veryVerbose: false,
                                       printState: false, printSlow: false, dumpTransactions: nil)
            let verbose = VerboseOutput(verbose: true, verboseFailed: false, veryVerbose: false,
                                        printState: false, printSlow: false, dumpTransactions: nil)
            let verboseFailed = VerboseOutput(verbose: false, verboseFailed: true, veryVerbose: false,
                                              printState: false, printSlow: false, dumpTransactions: nil)

            context("InvalidOpcode → skipped") {
                it("treats SLOAD (an unimplemented opcode) as skipped, not failed") {
                    // Code: PUSH1 0x00 SLOAD STOP
                    let code: [UInt8] = [0x60, 0x00, 0x54, 0x00]
                    let test = makeVmTestCase(code: code)
                    let r = VMRunner.run(name: "sload", test: test, verbose: silent)
                    expect(r.total).to(equal(1))
                    expect(r.skipped).to(equal(1))
                    expect(r.failed).to(equal(0))
                }
                it("emits a SKIP line in verbose mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x54, 0x00]
                    let test = makeVmTestCase(code: code)
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "sload", test: test, verbose: verbose)
                    }
                    expect(captured).to(contain("SKIP sload"))
                    expect(captured).to(contain("unimplemented opcode"))
                }
            }

            context("Success → passes when gas/output/post-state match expectations") {
                it("returns r.total = 1, r.failed = 0 when no expectations are present") {
                    // PUSH1 0x00 STOP
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code)
                    let r = VMRunner.run(name: "stop", test: test, verbose: silent)
                    expect(r.total).to(equal(1))
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                }
                it("matches an expected output produced by RETURN") {
                    // PUSH1 0x02 PUSH1 0x01 ADD PUSH1 0x00 MSTORE PUSH1 0x01 PUSH1 0x1f RETURN
                    // → returns 0x03
                    let code: [UInt8] = [0x60, 0x02, 0x60, 0x01, 0x01,
                                          0x60, 0x00, 0x52,
                                          0x60, 0x01, 0x60, 0x1f, 0xf3]
                    let test = makeVmTestCase(code: code, output: [0x03])
                    let r = VMRunner.run(name: "addRet", test: test, verbose: silent)
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                }
                it("fails when expected output doesn't match") {
                    let code: [UInt8] = [0x60, 0x02, 0x60, 0x01, 0x01,
                                          0x60, 0x00, 0x52,
                                          0x60, 0x01, 0x60, 0x1f, 0xf3]
                    let test = makeVmTestCase(code: code, output: [0x99])
                    let captured = captureStandardOutput {
                        let r = VMRunner.run(name: "addRet", test: test, verbose: verbose)
                        expect(r.failed).to(equal(1))
                    }
                    expect(captured).to(contain("FAIL addRet"))
                    expect(captured).to(contain("output mismatch"))
                }
                it("fails when expected gasLeft doesn't match") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLeft: U256(from: 1))
                    let r = VMRunner.run(name: "stop-gas", test: test, verbose: silent)
                    expect(r.failed).to(equal(1))
                }
                it("emits the gas-mismatch FAIL line in verbose mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLeft: U256(from: 1))
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "stop-gas", test: test, verbose: verbose)
                    }
                    expect(captured).to(contain("gas left mismatch"))
                }
                it("skips when post-state differs from pre-state (state mutation not implemented)") {
                    // PUSH1 0x00 STOP — post supplied but it's intentionally not equal to pre.
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let preAddr = h160LastByte(0xa1)
                    let env = StateEnv(
                        blockDifficulty: .ZERO, blockCoinbase: .ZERO, blockGasLimit: .ZERO,
                        blockNumber: U256(from: 1), blockTimestamp: U256(from: 1),
                        blockBaseFeePerGas: .ZERO, random: nil,
                        parentBlobGasUsed: nil, parentExcessBlobGas: nil, currentExcessBlobGas: nil
                    )
                    let exec = ExecutionTransaction(
                        address: preAddr, sender: h160LastByte(0xa2),
                        code: code, data: [],
                        gas: U256(from: 1_000_000), gasPrice: .ZERO,
                        origin: h160LastByte(0xa2), value: .ZERO, codeVersion: .ZERO
                    )
                    let pre = AccountsState([preAddr: StateAccount(nonce: .ZERO, balance: .ZERO, code: code, storage: [:])])
                    // Post deliberately includes an extra account so post != pre.
                    let post = AccountsState([
                        preAddr: StateAccount(nonce: .ZERO, balance: .ZERO, code: code, storage: [:]),
                        h160LastByte(0xff): StateAccount(nonce: .ZERO, balance: .ZERO, code: nil, storage: [:])
                    ])
                    let test = VmTestCase(calls: nil, env: env, transaction: exec,
                                          gasLeft: nil, logs: nil, output: nil,
                                          postState: post, preState: pre)
                    let captured = captureStandardOutput {
                        let r = VMRunner.run(name: "post-diff", test: test, verbose: verbose)
                        expect(r.skipped).to(equal(1))
                    }
                    expect(captured).to(contain("post-state differs from pre-state"))
                }
            }

            context("Revert path") {
                it("treats REVERT as a verified outcome (no expectations → counted as PASS)") {
                    // PUSH1 0x00 PUSH1 0x00 REVERT
                    let code: [UInt8] = [0x60, 0x00, 0x60, 0x00, 0xfd]
                    let test = makeVmTestCase(code: code)
                    let r = VMRunner.run(name: "rev", test: test, verbose: silent)
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                }
                it("emits a PASS-revert line in verbose mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x60, 0x00, 0xfd]
                    let test = makeVmTestCase(code: code)
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "rev", test: test, verbose: verbose)
                    }
                    expect(captured).to(contain("PASS rev (revert)"))
                }
            }

            context("Out-of-gas error") {
                it("counts as a failure when expectations are set") {
                    // PUSH1 0x00 STOP — but gasLimit too low to even charge the PUSH1
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLimitOverride: 1, output: [])
                    let r = VMRunner.run(name: "oog", test: test, verbose: silent)
                    expect(r.failed).to(equal(1))
                }
                it("does NOT fail when no expectations are present (matches Rust semantics for failing tests)") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLimitOverride: 1, postEqualsPre: false)
                    let r = VMRunner.run(name: "oog-no-expect", test: test, verbose: silent)
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                }
                it("emits the unexpected-exit-error FAIL line in verbose mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLimitOverride: 1, output: [])
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "oog-verbose", test: test, verbose: verbose)
                    }
                    expect(captured).to(contain("FAIL oog-verbose"))
                    expect(captured).to(contain("unexpected exit error"))
                }
                it("emits the unexpected-exit-error FAIL line in verboseFailed mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLimitOverride: 1, output: [])
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "oog-vf", test: test, verbose: verboseFailed)
                    }
                    expect(captured).to(contain("FAIL oog-vf"))
                }
            }

            context("verboseFailed branches in verifySuccess") {
                it("emits the gas-mismatch FAIL line in verboseFailed mode") {
                    let code: [UInt8] = [0x60, 0x00, 0x00]
                    let test = makeVmTestCase(code: code, gasLeft: U256(from: 1))
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "gas-vf", test: test, verbose: verboseFailed)
                    }
                    expect(captured).to(contain("gas left mismatch"))
                }
                it("emits the output-mismatch FAIL line in verboseFailed mode") {
                    let code: [UInt8] = [0x60, 0x02, 0x60, 0x01, 0x01,
                                          0x60, 0x00, 0x52,
                                          0x60, 0x01, 0x60, 0x1f, 0xf3]
                    let test = makeVmTestCase(code: code, output: [0x99])
                    let captured = captureStandardOutput {
                        _ = VMRunner.run(name: "out-vf", test: test, verbose: verboseFailed)
                    }
                    expect(captured).to(contain("output mismatch"))
                }
            }
        }
    }
}

private func makeVmTestCase(
    code: [UInt8],
    gasLimitOverride: UInt64? = nil,
    output: [UInt8]? = nil,
    gasLeft: U256? = nil,
    postEqualsPre: Bool = true
) -> VmTestCase {
    let addr = h160LastByte(0xa1)
    let env = StateEnv(
        blockDifficulty: .ZERO, blockCoinbase: .ZERO, blockGasLimit: .ZERO,
        blockNumber: U256(from: 1), blockTimestamp: U256(from: 1),
        blockBaseFeePerGas: .ZERO, random: nil,
        parentBlobGasUsed: nil, parentExcessBlobGas: nil, currentExcessBlobGas: nil
    )
    let exec = ExecutionTransaction(
        address: addr,
        sender: h160LastByte(0xa2),
        code: code,
        data: [],
        gas: U256(from: gasLimitOverride ?? 1_000_000),
        gasPrice: .ZERO,
        origin: h160LastByte(0xa2),
        value: .ZERO,
        codeVersion: .ZERO
    )
    let pre = AccountsState([addr: StateAccount(nonce: .ZERO, balance: .ZERO, code: code, storage: [:])])
    let post = postEqualsPre ? pre : nil
    return VmTestCase(
        calls: nil, env: env, transaction: exec,
        gasLeft: gasLeft, logs: nil, output: output,
        postState: post, preState: pre
    )
}
