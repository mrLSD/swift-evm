import Nimble
import Quick

@testable import PrimitiveTypes

final class ArithmeticShiftSpec: QuickSpec {
    override class func spec() {
        describe("U128.shiftLeft") {
            it("should return the same value when shifting by 0") {
                let value = U128(from: [0x1234567890abcdef, 0x0fedcba098765432])
                let shifted = value.shiftLeft(0)
                expect(shifted).to(equal(value))
            }

            it("should correctly shift left by 1 bit without carry") {
                let value = U128(from: [0x0000000000000001, 0x0000000000000000]) // 1
                let shifted = value.shiftLeft(1) // 2
                let expected = U128(from: [0x0000000000000002, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left by 1 bit with carry to high word") {
                let value = U128(from: [0x8000000000000000, 0x0000000000000000]) // 2^63
                let shifted = value.shiftLeft(1) // 2^64
                let expected = U128(from: [0x0000000000000000, 0x0000000000000001])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left by 63 bits with carry") {
                let value = U128(from: [0x0000000000000001, 0x0000000000000000]) // 1
                let shifted = value.shiftLeft(63) // 2^63
                let expected = U128(from: [0x8000000000000000, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left by exactly 64 bits") {
                let value = U128(from: [0x0000000000000001, 0x0000000000000000]) // 1
                let shifted = value.shiftLeft(64) // 1 * 2^64
                let expected = U128(from: [0x0000000000000000, 0x0000000000000001])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left by 65 bits with carry") {
                let value = U128(from: [0x0000000000000001, 0x0000000000000000]) // 1
                let shifted = value.shiftLeft(65) // 1 * 2^65
                let expected = U128(from: [0x0000000000000000, 0x0000000000000002])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left by 127 bits") {
                let value = U128(from: [0x0000000000000001, 0x0000000000000000]) // 1
                let shifted = value.shiftLeft(127) // 1 * 2^127
                let expected = U128(from: [0x0000000000000000, 0x8000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should return zero when shifting left by 128 bits") {
                let value = U128(from: [0xffffffffffffffff, 0xffffffffffffffff]) // Max U128
                let shifted = value.shiftLeft(128)
                let expected = U128.ZERO
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left a value with both low and high words set") {
                let value = U128(from: [0x00000000ffffffff, 0x00000000ffffffff])
                let shifted = value.shiftLeft(32)
                let expected = U128(from: [0xffffffff00000000, 0xffffffff00000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left a zero value") {
                let value = U128.ZERO
                let shifted = value.shiftLeft(10)
                let expected = U128.ZERO
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift left the maximum U128 value by 1 bit") {
                let value = U128.MAX // Max U128
                let shifted = value << 1
                let expected = U128(from: [0xfffffffffffffffe, UInt64.max])
                expect(shifted).to(equal(expected))
            }
        }

        describe("U128.shiftRight") {
            it("should return the same value when shifting by 0") {
                let value = U128(from: [0x1234567890abcdef, 0x0fedcba098765432])
                let shifted = value.shiftRight(0)
                expect(shifted).to(equal(value))
            }

            it("should correctly shift right by 1 bit without carry") {
                let value = U128(from: [0x0000000000000002, 0x0000000000000000]) // 2
                let shifted = value.shiftRight(1) // 1
                let expected = U128(from: [0x0000000000000001, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right by 1 bit with carry from high word") {
                let value = U128(from: [0x0000000000000000, 0x0000000000000001]) // 2^64
                let shifted = value.shiftRight(1) // 2^63
                let expected = U128(from: [0x8000000000000000, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right by 63 bits with carry") {
                let value = U128(from: [0x8000000000000000, 0x0000000000000000]) // 2^63
                let shifted = value.shiftRight(63) // 1
                let expected = U128(from: [0x0000000000000001, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right by exactly 64 bits") {
                let value = U128(from: [0x0000000000000000, 0x0000000000000001]) // 2^64
                let shifted = value.shiftRight(64) // 1
                let expected = U128(from: [0x0000000000000001, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right by 65 bits with carry") {
                let value = U128(from: [0x0000000000000000, 0x0000000000000002]) // 2^65
                let shifted = value.shiftRight(65) // 1
                let expected = U128(from: [0x0000000000000001, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right by 127 bits") {
                let value = U128(from: [0x0000000000000000, 0x8000000000000000]) // 2^127
                let shifted = value.shiftRight(127) // 1
                let expected = U128(from: [0x0000000000000001, 0x0000000000000000])
                expect(shifted).to(equal(expected))
            }

            it("should return zero when shifting right by 128 bits") {
                let value = U128(from: [0xffffffffffffffff, 0xffffffffffffffff]) // Max U128
                let shifted = value.shiftRight(128)
                let expected = U128.ZERO
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right a value with both low and high words set") {
                let value = U128(from: [0xfffffffa00000000, 0x00000000cfffffff])
                let shifted = value.shiftRight(20)
                let expected = U128(from: [0xffffffffffffa000, 0x0000000000000cff])
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right a zero value") {
                let value = U128.ZERO
                let shifted = value.shiftRight(10)
                let expected = U128.ZERO
                expect(shifted).to(equal(expected))
            }

            it("should correctly shift right the maximum U128 value by 1 bit") {
                let value = U128.MAX // Max U128
                let shifted = value >> 1
                let expected = U128(from: [UInt64.max, UInt64.max >> 1])
                expect(shifted).to(equal(expected))
            }
        }
    }
}
