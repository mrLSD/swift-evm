import Nimble
@testable import PrimitiveTypes
import XCTest

final class BitUintTests: XCTestCase {
    struct TestUint128: BigUInt {
        private let bytes: [UInt64]
        public static let numberBytes: UInt8 = 16
        public var BYTES: [UInt64] { bytes }

        public init(from value: [UInt64]) {
            precondition(value.count == Self.numberBase, "BigUInt must be initialized with \(Self.numberBase) UInt64 values.")
            self.bytes = value
        }
    }

    func testThrowInitWithPrecondition() {
        let errorMessage = captureStandardError {
            expect {
                let _ = TestUint128(from: [0, 0, 0, 0])
            }.to(throwAssertion())
        }
        expect(errorMessage).to(contain("must be initialized with 2 UInt64 values"))
    }

    func testThrowInitWithPrecondition2() {
        let errorMessage = captureStandardError {
            expect {
                let _ = U256(from: [0, 0])
            }.to(throwAssertion())
        }
        expect(errorMessage).to(contain("must be initialized with 4 UInt64 values"))
    }

    func testMax() throws {
        let val = TestUint128.MAX
        XCTAssertEqual(val.BYTES, [UInt64.max, UInt64.max])
        XCTAssert(!val.isZero)
        XCTAssertNotEqual(val, TestUint128(from: UInt64.max))
        XCTAssertEqual("\(val)", "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
        XCTAssertEqual(TestUint128.fromString(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"), val)
        XCTAssertEqual(val.toLittleEndian, [UInt8](repeating: 0xFF, count: 16))
        XCTAssertEqual(val.toBigEndian, [UInt8](repeating: 0xFF, count: 16))
        XCTAssertEqual(TestUint128.fromBigEndian(from: val.toBigEndian), val)
        XCTAssertEqual(TestUint128.fromLittleEndian(from: val.toLittleEndian), val)
    }

    func testZero() throws {
        let val = TestUint128.ZERO
        XCTAssertEqual(val.BYTES, [0, 0])
        XCTAssert(val.isZero)
        XCTAssertEqual(val, TestUint128(from: 0))
        XCTAssertEqual("\(val)", "00000000000000000000000000000000")
        XCTAssertEqual(TestUint128.fromString(hex: "00000000000000000000000000000000"), val)
        XCTAssertEqual(val.toLittleEndian, [UInt8](repeating: 0x0, count: 16))
        XCTAssertEqual(val.toBigEndian, [UInt8](repeating: 0x0, count: 16))
        XCTAssertEqual(TestUint128.fromBigEndian(from: val.toBigEndian), val)
        XCTAssertEqual(TestUint128.fromLittleEndian(from: val.toLittleEndian), val)
    }
}
