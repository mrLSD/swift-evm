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
                        let account = BasicAccount(balance: hundred, nonce: one)
                        expect(account.balance).to(equal(hundred))
                        expect(account.nonce).to(equal(one))
                    }
                }

                context("mutations") {
                    it("should increment nonce") {
                        var account = BasicAccount(balance: hundred, nonce: zero)

                        account.incNonce()
                        expect(account.nonce).to(equal(one))

                        account.incNonce()
                        expect(account.nonce).to(equal(U256(from: 2)))
                    }

                    it("should set balance") {
                        var account = BasicAccount(balance: hundred, nonce: zero)
                        account.setBalance(zero)

                        expect(account.balance).to(equal(zero))
                    }
                }

                context("saturating arithmetic") {
                    it("should add balance normally without overflow") {
                        var account = BasicAccount(balance: hundred, nonce: zero)
                        account.addBalance(hundred)
                        expect(account.balance).to(equal(U256(from: 200)))
                    }

                    it("should cap at MAX on balance overflow (saturating add)") {
                        var account = BasicAccount(balance: maxU256, nonce: zero)
                        account.addBalance(one)
                        expect(account.balance).to(equal(maxU256))
                    }

                    it("should subtract balance normally without underflow") {
                        var account = BasicAccount(balance: hundred, nonce: zero)
                        account.subBalance(one)
                        expect(account.balance).to(equal(U256(from: 99)))
                    }

                    it("should cap at ZERO on balance underflow (saturating sub)") {
                        var account = BasicAccount(balance: hundred, nonce: zero)
                        account.subBalance(U256(from: 101))
                        expect(account.balance).to(equal(zero))
                    }
                }
            }

            describe("StateAccount") {
                let basic = BasicAccount(balance: hundred, nonce: one)

                it("should initialize with provided values") {
                    let state = StateAccount(basic: basic, code: codeSample, reset: true)
                    expect(state.basic).to(equal(basic))
                    expect(state.code).to(equal(codeSample))
                    expect(state.reset).to(beTrue())
                }

                context("Equality (Equatable)") {
                    let state1 = StateAccount(basic: basic, code: codeSample, reset: false)

                    it("should be equal to an identical instance") {
                        let state2 = StateAccount(basic: basic, code: codeSample, reset: false)
                        expect(state1).to(equal(state2))
                    }

                    it("should not be equal if basic info differs") {
                        let differentBasic = BasicAccount(balance: zero, nonce: zero)
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

                    it("should not be equal if reset flag differs") {
                        let state2 = StateAccount(basic: basic, code: codeSample, reset: true)
                        expect(state1).toNot(equal(state2))
                    }
                }
            }
        }
    }
}
