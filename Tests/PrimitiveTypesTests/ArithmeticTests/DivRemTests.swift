import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticDivRemSpec: QuickSpec {
    override class func spec() {
        describe("divRem operation") {
            context("common division cases") {
                it("dividing by one") {
                    let a = U256(from: [1, 2, 3, 4])
                    let b = U256(from: [1, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([1, 2, 3, 4]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }

                it("success divide works for a /= operation") {
                    var a = U256(from: 6)
                    let b = U256(from: 3)
                    a /= b
                    let result = a

                    expect(result).to(equal(U256(from: 2)))
                }

                it("success divide works for a %= operation") {
                    var a = U256(from: 5)
                    let b = U256(from: 3)
                    a %= b
                    let result = a

                    expect(result).to(equal(U256(from: 2)))
                }

                it("dividing max value by one") {
                    let a = U256.MAX
                    let b = U256(from: [1, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([UInt64.max, UInt64.max, UInt64.max, UInt64.max]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }

                it("dividing by max value") {
                    let a = U256.MAX
                    let b = U256(from: [UInt64.max, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([1, 1, 1, 1]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }

                it("partial remainder when dividing") {
                    let a = U256(from: [1, 2, 3, 4])
                    let b = U256(from: [2, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([0, 0x8000000000000001, 1, 2]))
                    expect(remainder.BYTES).to(equal([1, 0, 0, 0]))
                }

                it("large number division") {
                    let a = U256(from: [100, 200, 300, 400])
                    let b = U256(from: [5, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([20, 40, 60, 80]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }
            }

            context("edge cases") {
                it("dividing by zero") {
                    let a = U256(from: [1, 2, 3, 4])
                    let b = U256(from: [0, 0, 0, 0])

                    expect(captureStandardError {
                        expect {
                            _ = a.divRem(divisor: b)
                        }.to(throwAssertion())
                    }).to(contain("Division by zero"))
                }

                it("dividing zero by any number") {
                    let a = U256(from: [0, 0, 0, 0])
                    let b = U256(from: [1, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([0, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }

                it("dividing by a larger number") {
                    let a = U256(from: [1, 0, 0, 0])
                    let b = U256(from: [2, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([0, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([1, 0, 0, 0]))
                }

                it("dividing max value by half of max") {
                    let a = U256(from: [UInt64.max, 0, 0, 0])
                    let b = U256(from: [UInt64.max/2, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([2, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([1, 0, 0, 0]))
                }

                it("partial overflow during division") {
                    let a = U256(from: [UInt64.max, 1, 0, 0])
                    let b = U256(from: [2, 0, 0, 0])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([UInt64.max, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([1, 0, 0, 0]))
                }

                it("partial case 2") {
                    let a = U256(from: [UInt64.max/2, 1, UInt64.max/2, 0])
                    let b = U256(from: [2, UInt64.max/2, 0, 0])
                    let quotient = a/b
                    let remainder = a % b

                    expect(quotient.BYTES).to(equal([UInt64.max, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([0x8000000000000001, 0x7ffffffffffffffe, 0, 0]))
                }

                it("partial case 2 - multi-word divisor") {
                    let a = U256(from: [UInt64.max/2, 1, UInt64.max/3, UInt64.max/2])
                    let b = U256(from: [0, UInt64.max/2, 1, UInt64.max/4])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([2, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([0x7fffffffffffffff, 3, 0x5555555555555552, 1]))
                }

                it("partial case 3") {
                    let a = U256(from: [UInt64.max - 1, UInt64.max - 1, UInt64.max - 1, UInt64.max - 1])
                    let b = U256(from: UInt64.max - 1)
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([1, 1, 1, 1]))
                    expect(remainder.BYTES).to(equal([0, 0, 0, 0]))
                }

                it("partial case 3 - dividend smaller than divisor") {
                    let a = U256(from: UInt64.max - 1)
                    let b = U256(from: [UInt64.max - 1, UInt64.max - 1, UInt64.max - 1, UInt64.max - 1])
                    let (quotient, remainder) = a.divRem(divisor: b)

                    expect(quotient.BYTES).to(equal([0, 0, 0, 0]))
                    expect(remainder.BYTES).to(equal([18446744073709551614, 0, 0, 0]))
                }
            }

            context("divmodWord for non UInt128") {
                it("100 / 2") {
                    let (div, rem) = DivModUtils.divModWord64(hi: 0, lo: 100, y: 2)

                    expect(div).to(equal(50))
                    expect(rem).to(equal(0))
                }

                it("100 / 6") {
                    let (div, rem) = DivModUtils.divModWord64(hi: 0, lo: 100, y: 6)

                    expect(div).to(equal(16))
                    expect(rem).to(equal(4))
                }

                it("hi 100 / 6") {
                    let (div, rem) = DivModUtils.divModWord64(hi: 100, lo: 0, y: 6)

                    expect(div).to(equal(UInt64.max))
                    expect(rem).to(equal(6))
                }

                it("fuzz single random pair 1") {
                    let a = UInt64.random(in: 1..<UInt64.max)
                    let b = UInt64.random(in: 1..<UInt64.max)
                    let (div, rem) = DivModUtils.divModWord64(hi: 0, lo: a, y: b)

                    expect(div).to(equal(a/b))
                    expect(rem).to(equal(a % b))
                }

                it("fuzz single random pair 2") {
                    let a = UInt64.random(in: 1..<UInt64.max)
                    let b = UInt64.random(in: 1..<UInt64.max)
                    let (div, rem) = DivModUtils.divModWord64(hi: 0, lo: a, y: b)

                    expect(div).to(equal(a/b))
                    expect(rem).to(equal(a % b))
                }
            }

            context("addSlice") {
                it("case 1") {
                    var a: [UInt64] = [1, 2, 3, 4]
                    let b: [UInt64] = [5, 6]
                    let from = 1
                    let to = 3

                    let expectedA: [UInt64] = [0x1, 0x7, 0x9, 0x4]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 2") {
                    var a: [UInt64] = [0xffffffffffffffff, 0x0, 0x0]
                    let b: [UInt64] = [1]
                    let from = 0
                    let to = 1

                    let expectedA: [UInt64] = [0x0, 0x0, 0x0]
                    let expectedCarry = true

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 3") {
                    var a: [UInt64] = [0xffffffffffffffff, 0xffffffffffffffff, 0x0]
                    let b: [UInt64] = [1, 1]
                    let from = 0
                    let to = 2

                    let expectedA: [UInt64] = [0x0, 0x1, 0x0]
                    let expectedCarry = true

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 4") {
                    var a: [UInt64] = [1, 2, 3, 4]
                    let b: [UInt64] = [5, 6, 7]
                    let from = 1
                    let to = 2

                    let expectedA: [UInt64] = [1, 7, 9, 4]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 5") {
                    var a: [UInt64] = [10, 20, 30, 40]
                    let b: [UInt64] = [0, 0]
                    let from = 1
                    let to = 3

                    let expectedA: [UInt64] = [10, 20, 30, 40]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 6") {
                    var a: [UInt64] = [1, 2, 3]
                    let b: [UInt64] = [4, 5, 6]
                    let from = 2
                    let to = 3

                    let expectedA: [UInt64] = [1, 2, 7]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 7") {
                    var a: [UInt64] = [UInt64.max, UInt64.max, UInt64.max]
                    let b: [UInt64] = [1, 1, 1]
                    let from = 0
                    let to = 3

                    let expectedA: [UInt64] = [0, 1, 1]
                    let expectedCarry = true

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 8") {
                    var a: [UInt64] = [1, 2, 3, 4]
                    let b: [UInt64] = []
                    let from = 0
                    let to = 4

                    let expectedA: [UInt64] = [1, 2, 3, 4]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 9") {
                    var a: [UInt64] = [0, 0, 0]
                    let b: [UInt64] = [0, 0]
                    let from = 1
                    let to = 3

                    let expectedA: [UInt64] = [0, 0, 0]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }

                it("case 10") {
                    var a: [UInt64] = [1, 2, 3]
                    let b: [UInt64] = [4, 5, 6, 7]
                    let from = 0
                    let to = 3

                    let expectedA: [UInt64] = [5, 7, 9]
                    let expectedCarry = false

                    let carry = U256.addSlice(a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(carry).to(equal(expectedCarry))
                }
            }

            context("carry addSlice") {
                it("without carry") {
                    var a: [UInt64] = [1, 2, 3, 4]
                    let b: [UInt64] = [5, 6]
                    let from = 1
                    let to = 2
                    var q_hat: UInt64 = 4

                    let expectedA: [UInt64] = [0x1, 0x7, 0x9, 0x4]

                    U256.carryAddSlice(carry: true, q_hat: &q_hat, a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(q_hat).to(equal(3))
                }

                it("with carry") {
                    var a: [UInt64] = [0xffffffffffffffff, 0xffffffffffffffff, 0x0]
                    let b: [UInt64] = [1, 1]
                    let from = 0
                    let to = 2
                    var q_hat: UInt64 = 4

                    let expectedA: [UInt64] = [0x0, 0x1, 0x1]

                    U256.carryAddSlice(carry: true, q_hat: &q_hat, a: &a, from: from, b: b, to: to)
                    expect(a).to(equal(expectedA))
                    expect(q_hat).to(equal(3))
                }
            }
        }
    }
}
