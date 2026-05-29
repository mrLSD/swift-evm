@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class SkipListSpec: QuickSpec {
    override class func spec() {
        describe("SkipList type") {
            context("static catalogues") {
                it("alwaysSkipped contains exactly the gated-cargo-feature entries") {
                    expect(SkipList.alwaysSkipped).to(contain("stTransactionTest/ValueOverflow"))
                    expect(SkipList.alwaysSkipped).to(contain("stRevertTest/RevertPrecompiledTouch"))
                    expect(SkipList.alwaysSkipped).to(contain("eip7702_set_code_tx/set_code_txs/tx_validity_nonce"))
                    expect(SkipList.alwaysSkipped).toNot(contain("vmPerformance/loopMul"))
                }
                it("slowOnly contains the three slow-test entries") {
                    expect(SkipList.slowOnly).to(equal([
                        "stTimeConsuming/static_Call50000_sha256",
                        "vmPerformance/loopMul",
                        "stTimeConsuming/CALLBlake2f_MaxRounds"
                    ]))
                }
            }

            context("shouldSkip — default (slow tests included in skip list)") {
                it("matches a 2-component case as a path suffix") {
                    expect(SkipList.shouldSkip("/tmp/foo/stTransactionTest/ValueOverflow.json")).to(beTrue())
                    expect(SkipList.shouldSkip("stTransactionTest/ValueOverflow.json")).to(beTrue())
                }
                it("does NOT match when the parent is wrong") {
                    expect(SkipList.shouldSkip("/tmp/other/ValueOverflow.json")).to(beFalse())
                }
                it("matches when the case path appears as a contiguous mid-path window") {
                    expect(SkipList.shouldSkip("/tests/eip7702_set_code_tx/set_code_txs/tx_validity_nonce.json")).to(beTrue())
                }
                it("matches the slow tests by default") {
                    expect(SkipList.shouldSkip("/repo/stTimeConsuming/static_Call50000_sha256.json")).to(beTrue())
                    expect(SkipList.shouldSkip("/repo/vmPerformance/loopMul.json")).to(beTrue())
                }
                it("does not match arbitrary unrelated paths") {
                    expect(SkipList.shouldSkip("/tmp/whatever/other_test.json")).to(beFalse())
                    expect(SkipList.shouldSkip("/tmp/stTransactionTest/Other.json")).to(beFalse())
                }
                it("returns false for the empty path") {
                    expect(SkipList.shouldSkip("")).to(beFalse())
                }
            }

            context("shouldSkip — enableSlowTests = true") {
                it("does NOT match the slow tests") {
                    expect(SkipList.shouldSkip("/repo/stTimeConsuming/static_Call50000_sha256.json", enableSlowTests: true)).to(beFalse())
                    expect(SkipList.shouldSkip("/repo/vmPerformance/loopMul.json", enableSlowTests: true)).to(beFalse())
                    expect(SkipList.shouldSkip("/repo/stTimeConsuming/CALLBlake2f_MaxRounds.json", enableSlowTests: true)).to(beFalse())
                }
                it("still matches always-skipped cases") {
                    expect(SkipList.shouldSkip("/tmp/foo/stTransactionTest/ValueOverflow.json", enableSlowTests: true)).to(beTrue())
                    expect(SkipList.shouldSkip("/tests/eip7702_set_code_tx/set_code_txs/tx_validity_nonce.json", enableSlowTests: true)).to(beTrue())
                }
            }
        }
    }
}
