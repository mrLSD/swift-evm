@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class StateRunnerSpec: QuickSpec {
    override class func spec() {
        describe("StateRunner.run") {
            let silent = VerboseOutput(verbose: false, verboseFailed: false, veryVerbose: false,
                                       printState: false, printSlow: false, dumpTransactions: nil)
            let veryVerbose = VerboseOutput(verbose: false, verboseFailed: false, veryVerbose: true,
                                            printState: false, printSlow: false, dumpTransactions: nil)

            context("empty post_states") {
                it("returns an empty result when there are no specs to evaluate") {
                    let tc = makeStateTestCase(postStates: [:])
                    let r = StateRunner.run(name: "t", test: tc, specFilter: nil, verbose: silent)
                    expect(r.total).to(equal(0))
                    expect(r.skipped).to(equal(0))
                    expect(r.failed).to(equal(0))
                }
            }

            context("spec filter") {
                it("skips entire spec entries that don't match the --spec filter") {
                    let post = [makePostState()]
                    let tc = makeStateTestCase(postStates: [.Cancun: post])
                    let r = StateRunner.run(name: "t", test: tc, specFilter: .Prague, verbose: silent)
                    expect(r.total).to(equal(0))
                }
                it("processes only the matching spec entries") {
                    let cancunPosts = [makePostState(), makePostState()]
                    let praguePosts = [makePostState()]
                    let tc = makeStateTestCase(postStates: [.Cancun: cancunPosts, .Prague: praguePosts])
                    let r = StateRunner.run(name: "t", test: tc, specFilter: .Cancun, verbose: silent)
                    expect(r.total).to(equal(2))
                }
            }

            context("pre-Istanbul forks (no executable config)") {
                it("skips with all post-states counted as skipped") {
                    let posts = [makePostState(), makePostState(), makePostState()]
                    let tc = makeStateTestCase(postStates: [.Byzantium: posts])
                    let r = StateRunner.run(name: "t", test: tc, specFilter: nil, verbose: silent)
                    expect(r.total).to(equal(3))
                    expect(r.skipped).to(equal(3))
                    expect(r.failed).to(equal(0))
                }
                it("emits a SKIP line in very-verbose mode") {
                    let tc = makeStateTestCase(postStates: [.Byzantium: [makePostState()]])
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(name: "preIstanbul", test: tc, specFilter: nil, verbose: veryVerbose)
                    }
                    expect(captured).to(contain("preIstanbul"))
                    expect(captured).to(contain("Byzantium"))
                    expect(captured).to(contain("no executable config"))
                }
            }

            context("transactor stub path") {
                it("skips when sender is missing (secp256k1 recovery not implemented)") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        sender: nil
                    )
                    let r = StateRunner.run(name: "no-sender", test: tc, specFilter: nil, verbose: silent)
                    expect(r.total).to(equal(1))
                    expect(r.skipped).to(equal(1))
                    expect(r.failed).to(equal(0))
                }
                it("emits the no-sender SKIP line in very-verbose mode") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        sender: nil
                    )
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(name: "no-sender", test: tc, specFilter: nil, verbose: veryVerbose)
                    }
                    expect(captured).to(contain("no-sender"))
                    expect(captured).to(contain("secp256k1 caller recovery is not implemented"))
                }
                it("skips a CALL transaction (transactor.call throws notImplemented)") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let r = StateRunner.run(name: "call", test: tc, specFilter: nil, verbose: silent)
                    expect(r.skipped).to(equal(1))
                    expect(r.failed).to(equal(0))
                }
                it("skips a CREATE transaction (transactor.create throws notImplemented)") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: nil
                    )
                    let r = StateRunner.run(name: "create", test: tc, specFilter: nil, verbose: silent)
                    expect(r.skipped).to(equal(1))
                    expect(r.failed).to(equal(0))
                }
                it("emits the transactor SKIP reason in very-verbose mode") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(name: "call", test: tc, specFilter: nil, verbose: veryVerbose)
                    }
                    expect(captured).to(contain("transact_call: see Transactor.swift"))
                }
            }

            context("injected transactor — success path") {
                it("counts a successful call as PASS, not skipped") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let okCall: StateRunner.TransactFn = { _, _ in
                        Transactor.Output(exitReason: .Success(.Stop), returnData: [], gasUsed: 0)
                    }
                    let okCreate: StateRunner.TransactFn = { _, _ in
                        Transactor.Output(exitReason: .Success(.Stop), returnData: [], gasUsed: 0)
                    }
                    let r = StateRunner.run(
                        name: "ok", test: tc, specFilter: nil, verbose: silent,
                        transactCall: okCall, transactCreate: okCreate
                    )
                    expect(r.total).to(equal(1))
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                }
                it("emits the PASS line in verbose mode") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let verbose = VerboseOutput(verbose: true, verboseFailed: false, veryVerbose: false,
                                                printState: false, printSlow: false, dumpTransactions: nil)
                    let okCall: StateRunner.TransactFn = { _, _ in
                        Transactor.Output(exitReason: .Success(.Stop), returnData: [], gasUsed: 0)
                    }
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(
                            name: "ok", test: tc, specFilter: nil, verbose: verbose,
                            transactCall: okCall, transactCreate: okCall
                        )
                    }
                    expect(captured).to(contain("PASS ok [Cancun]"))
                }
                it("dispatches CREATE through transactCreate when transaction.to is nil") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: nil
                    )
                    var createCalled = false
                    var callCalled = false
                    let okCreate: StateRunner.TransactFn = { _, _ in
                        createCalled = true
                        return Transactor.Output(exitReason: .Success(.Stop), returnData: [], gasUsed: 0)
                    }
                    let okCall: StateRunner.TransactFn = { _, _ in
                        callCalled = true
                        return Transactor.Output(exitReason: .Success(.Stop), returnData: [], gasUsed: 0)
                    }
                    _ = StateRunner.run(
                        name: "create", test: tc, specFilter: nil, verbose: silent,
                        transactCall: okCall, transactCreate: okCreate
                    )
                    expect(createCalled).to(beTrue())
                    expect(callCalled).to(beFalse())
                }
            }

            context("injected transactor — non-NotImplemented error") {
                struct OtherError: Error, Equatable {}

                it("counts as failed and emits FAIL line in verbose mode") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let verbose = VerboseOutput(verbose: true, verboseFailed: false, veryVerbose: false,
                                                printState: false, printSlow: false, dumpTransactions: nil)
                    let throwingCall: StateRunner.TransactFn = { _, _ in throw OtherError() }
                    let captured = captureStandardOutput {
                        let r = StateRunner.run(
                            name: "boom", test: tc, specFilter: nil, verbose: verbose,
                            transactCall: throwingCall, transactCreate: throwingCall
                        )
                        expect(r.failed).to(equal(1))
                    }
                    expect(captured).to(contain("FAIL boom [Cancun]"))
                }
                it("emits FAIL line in verboseFailed mode (right-hand of OR)") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let verboseFailed = VerboseOutput(verbose: false, verboseFailed: true, veryVerbose: false,
                                                      printState: false, printSlow: false, dumpTransactions: nil)
                    let throwingCall: StateRunner.TransactFn = { _, _ in throw OtherError() }
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(
                            name: "boom", test: tc, specFilter: nil, verbose: verboseFailed,
                            transactCall: throwingCall, transactCreate: throwingCall
                        )
                    }
                    expect(captured).to(contain("FAIL boom"))
                }
                it("counts as failed (silent mode does not print)") {
                    let tc = makeStateTestCase(
                        postStates: [.Cancun: [makePostState()]],
                        to: h160LastByte(0xab)
                    )
                    let throwingCall: StateRunner.TransactFn = { _, _ in throw OtherError() }
                    let r = StateRunner.run(
                        name: "boom", test: tc, specFilter: nil, verbose: silent,
                        transactCall: throwingCall, transactCreate: throwingCall
                    )
                    expect(r.failed).to(equal(1))
                }
            }

            context("deterministic spec ordering") {
                it("iterates specs sorted by rawValue") {
                    let posts = [makePostState()]
                    let tc = makeStateTestCase(
                        postStates: [.Prague: posts, .Cancun: posts, .Berlin: posts]
                    )
                    let captured = captureStandardOutput {
                        _ = StateRunner.run(name: "ord", test: tc, specFilter: nil, verbose: veryVerbose)
                    }
                    let berlinIdx = captured.range(of: "Berlin")?.lowerBound
                    let cancunIdx = captured.range(of: "Cancun")?.lowerBound
                    let pragueIdx = captured.range(of: "Prague")?.lowerBound
                    expect(berlinIdx).toNot(beNil())
                    expect(cancunIdx).toNot(beNil())
                    expect(pragueIdx).toNot(beNil())
                    expect(berlinIdx! < cancunIdx!).to(beTrue())
                    expect(cancunIdx! < pragueIdx!).to(beTrue())
                }
            }
        }
    }
}

private func makeStateTestCase(
    postStates: [Spec: [PostState]],
    sender: H160? = h160LastByte(0xaa),
    to: H160? = h160LastByte(0xbb)
) -> StateTestCase {
    let env = StateEnv(
        blockDifficulty: .ZERO, blockCoinbase: .ZERO, blockGasLimit: U256(from: 1_000_000),
        blockNumber: U256(from: 1), blockTimestamp: U256(from: 1),
        blockBaseFeePerGas: .ZERO, random: nil,
        parentBlobGasUsed: nil, parentExcessBlobGas: nil, currentExcessBlobGas: nil
    )
    let pre = PreState(accounts: AccountsState([:]))
    let tx = Transaction(
        txType: nil, data: [[]], gasLimit: [U256(from: 21000)],
        gasPrice: U256(from: 1), nonce: .ZERO,
        secretKey: nil, sender: sender, to: to,
        value: [.ZERO],
        maxFeePerGas: nil, maxPriorityFeePerGas: nil,
        initCodes: nil, accessLists: [],
        blobVersionedHashes: [], maxFeePerBlobGas: nil,
        authorizationList: nil
    )
    return StateTestCase(env: env, preState: pre, postStates: postStates,
                         transaction: tx, out: nil, info: nil)
}

private func makePostState() -> PostState {
    return PostState(
        hash: h256LastByte(0x01),
        logs: h256LastByte(0x02),
        indexes: PostStateIndexes(data: 0, gas: 0, value: 0),
        expectException: nil,
        txBytes: [0xf8],
        state: nil,
        postState: nil
    )
}
