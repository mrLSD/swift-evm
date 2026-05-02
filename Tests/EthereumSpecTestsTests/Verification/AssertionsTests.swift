@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import Quick

final class AssertionsSpec: QuickSpec {
    override class func spec() {
        describe("Assertions type") {
            context("matchesValidation") {
                it("matches OutOfFund accepted strings") {
                    expect(Assertions.matchesValidation(reason: .outOfFund, expected: "TR_NoFunds", spec: .Cancun)).to(beTrue())
                    expect(Assertions.matchesValidation(reason: .outOfFund, expected: "TransactionException.INSUFFICIENT_ACCOUNT_FUNDS", spec: .Prague)).to(beTrue())
                }
                it("rejects mismatched strings") {
                    expect(Assertions.matchesValidation(reason: .outOfFund, expected: "Bogus", spec: .Cancun)).to(beFalse())
                }
                it("uses spec override when present (Prague narrows priorityFeeTooLarge)") {
                    expect(Assertions.matchesValidation(reason: .priorityFeeTooLarge, expected: "tipTooHigh", spec: .Prague)).to(beFalse())
                    expect(Assertions.matchesValidation(reason: .priorityFeeTooLarge, expected: "TransactionException.PRIORITY_GREATER_THAN_MAX_FEE_PER_GAS", spec: .Prague)).to(beTrue())
                    expect(Assertions.matchesValidation(reason: .priorityFeeTooLarge, expected: "tipTooHigh", spec: .London)).to(beTrue())
                }
                it("falls back to the union table when no spec override is registered") {
                    expect(Assertions.matchesValidation(reason: .intrinsicGas, expected: "TR_IntrinsicGas", spec: .Cancun)).to(beTrue())
                    expect(Assertions.matchesValidation(reason: .intrinsicGas, expected: "Nope", spec: .Cancun)).to(beFalse())
                }
                it("returns false for any reason that has no entry in the table") {
                    expect(Assertions.matchesValidation(reason: .invalidAuthorizationChain, expected: "Bogus", spec: .Prague)).to(beFalse())
                }
            }

            context("matchesCreateExit") {
                it("accepts MaxNonce strings") {
                    expect(Assertions.matchesCreateExit(error: .MaxNonce, expected: "TR_NonceHasMaxValue")).to(beTrue())
                    expect(Assertions.matchesCreateExit(error: .MaxNonce, expected: "TransactionException.NONCE_IS_MAX")).to(beTrue())
                }
                it("accepts OutOfGas string") {
                    expect(Assertions.matchesCreateExit(error: .OutOfGas, expected: "TransactionException.INTRINSIC_GAS_TOO_LOW")).to(beTrue())
                }
                it("rejects unrelated strings") {
                    expect(Assertions.matchesCreateExit(error: .MaxNonce, expected: "TR_NoFunds")).to(beFalse())
                }
                it("returns false for an exit error with no registered exception strings") {
                    expect(Assertions.matchesCreateExit(error: .StackUnderflow, expected: "Anything")).to(beFalse())
                }
            }

            context("matchesEmptyCreateCaller") {
                it("accepts both EIP-3607 spellings") {
                    expect(Assertions.matchesEmptyCreateCaller(expected: "SenderNotEOA")).to(beTrue())
                    expect(Assertions.matchesEmptyCreateCaller(expected: "TransactionException.SENDER_NOT_EOA")).to(beTrue())
                }
                it("rejects other strings") {
                    expect(Assertions.matchesEmptyCreateCaller(expected: "Other")).to(beFalse())
                    expect(Assertions.matchesEmptyCreateCaller(expected: "")).to(beFalse())
                }
            }

            context("createExitErrorExceptions") {
                it("returns an empty set for unmapped exit errors") {
                    expect(Assertions.createExitErrorExceptions(.StackUnderflow)).to(beEmpty())
                    expect(Assertions.createExitErrorExceptions(.InvalidJump)).to(beEmpty())
                }
            }
        }
    }
}
