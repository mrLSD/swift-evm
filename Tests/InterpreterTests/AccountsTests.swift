@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class AccountSpec: QuickSpec {
    override class func spec() {
        describe("Account Types") {
            let zero = U256.ZERO
            let one = U256(from: 1)
            let hundred = U256(from: 100)
            let maxU256 = U256.MAX

            let codeSample: [UInt8] = [0x60, 0x00, 0x60, 0x00, 0xf3] // RETURN(0,0)

            describe("BasicAccount") {
                context("initialization") {
                    it("should correctly set initial balance and nonce") {
                        let account = BasicAccount(balance: hundred, nonce: 1)
                        expect(account.balance).to(equal(hundred))
                        expect(account.nonce).to(equal(UInt64(1)))
                    }
                }

                context("mutations") {
                    it("should increment nonce") {
                        var account = BasicAccount(balance: hundred, nonce: 0)

                        account.incNonce()
                        expect(account.nonce).to(equal(UInt64(1)))

                        account.incNonce()
                        expect(account.nonce).to(equal(UInt64(2)))
                    }

                    // Regression: `incNonce()` must use checked `+= 1` (not wrapping `&+= 1`).
                    // If the caller skips the `MaxNonce` guard in `MemoryState.incNonce` and invokes
                    // this directly with `nonce == UInt64.max`, the overflow MUST trap loudly —
                    // silent wrap-around to 0 would mask a serious caller-side bug.
                    it("traps on UInt64.max + 1 (no silent wrap)") {
                        var account = BasicAccount(balance: hundred, nonce: UInt64.max)
                        expect {
                            account.incNonce()
                        }.to(throwAssertion())
                    }

                    it("should set balance") {
                        var account = BasicAccount(balance: hundred, nonce: 0)
                        account.setBalance(zero)

                        expect(account.balance).to(equal(zero))
                    }
                }

                context("saturating arithmetic") {
                    it("should add balance normally without overflow") {
                        var account = BasicAccount(balance: hundred, nonce: 0)
                        account.addBalance(hundred)
                        expect(account.balance).to(equal(U256(from: 200)))
                    }

                    it("should cap at MAX on balance overflow (saturating add)") {
                        var account = BasicAccount(balance: maxU256, nonce: 0)
                        account.addBalance(one)
                        expect(account.balance).to(equal(maxU256))
                    }

                    it("should subtract balance normally without underflow") {
                        var account = BasicAccount(balance: hundred, nonce: 0)
                        account.subBalance(one)
                        expect(account.balance).to(equal(U256(from: 99)))
                    }

                    it("should cap at ZERO on balance underflow (saturating sub)") {
                        var account = BasicAccount(balance: hundred, nonce: 0)
                        account.subBalance(U256(from: 101))
                        expect(account.balance).to(equal(zero))
                    }
                }
            }

            describe("StateAccount") {
                let basic = BasicAccount(balance: hundred, nonce: 1)
                // `cast keccak` reference digests of `codeSample` and of "abc".
                let codeSampleHash = try! H256.fromString(hex: "d003426e799329b8dca093f3bbab55a5e4e9f3c40160fc942068eef712ae88ad").get()
                let abcHash = try! H256.fromString(hex: "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45").get()

                it("should initialize with provided values") {
                    let state = StateAccount(basic: basic, code: codeSample, reset: true)
                    expect(state.basic).to(equal(basic))
                    expect(state.code).to(equal(codeSample))
                    expect(state.codeHash).to(equal(codeSampleHash))
                    expect(state.reset).to(beTrue())
                }

                it("should leave the hash of unknown code unset and use KECCAK_EMPTY for empty code") {
                    expect(StateAccount(basic: basic, code: nil, reset: false).codeHash).to(beNil())
                    expect(StateAccount(basic: basic, code: [], reset: false).codeHash).to(equal(H256.KECCAK_EMPTY))
                }

                it("should replace code together with its hash") {
                    var state = StateAccount(basic: basic, code: nil, reset: true)
                    state.setCode([0x61, 0x62, 0x63])
                    expect(state.code).to(equal([0x61, 0x62, 0x63]))
                    expect(state.codeHash).to(equal(abcHash))

                    state.setCode([])
                    expect(state.code).to(equal([]))
                    expect(state.codeHash).to(equal(H256.KECCAK_EMPTY))
                    expect(state.basic).to(equal(basic))
                    expect(state.reset).to(beTrue())
                }

                context("Equality (Equatable)") {
                    let state1 = StateAccount(basic: basic, code: codeSample, reset: false)

                    it("should be equal to an identical instance") {
                        let state2 = StateAccount(basic: basic, code: codeSample, reset: false)
                        expect(state1).to(equal(state2))
                    }

                    it("should not be equal if basic info differs") {
                        let differentBasic = BasicAccount(balance: zero, nonce: 0)
                        let state2 = StateAccount(basic: differentBasic, code: codeSample, reset: false)
                        expect(state1).toNot(equal(state2))
                    }

                    it("should not be equal if code differs") {
                        let state2 = StateAccount(basic: basic, code: [0x00], reset: false)
                        expect(state1).toNot(equal(state2))
                    }

                    it("should not be equal if one code is nil") {
                        let state2 = StateAccount(basic: basic, code: nil, reset: false)
                        expect(state1).toNot(equal(state2))
                    }

                    it("should not be equal if code hash differs") {
                        var state2 = state1
                        state2.codeHash = .ZERO
                        expect(state1).toNot(equal(state2))
                    }

                    it("should not be equal if reset flag differs") {
                        let state2 = StateAccount(basic: basic, code: codeSample, reset: true)
                        expect(state1).toNot(equal(state2))
                    }
                }
            }
        }
    }
}
