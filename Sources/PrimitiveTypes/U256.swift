import Foundation

public struct U256: BigUInt {
    private let bytes: [UInt64]

    public static let ZERO: Self = .init(from: [0, 0, 0, 0])
    public static let MAX: Self = .init(from: [0xFF, 0xFF, 0xFF, 0xFF])
    public static let numberBytes: UInt8 = 32
    public var BYTES: [UInt64] { self.bytes }

    public init(from value: [UInt64]) {
        let doubleWord = Self.numberBytes / 8
        precondition(value.count == doubleWord, "BigUInt must be initialized with \(doubleWord) UInt64 values.")

        self.bytes = value
    }
}
