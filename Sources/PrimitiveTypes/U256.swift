import Foundation

public struct U256: BigUInt {
    private let bytes: [UInt64]

    public static let numberBytes: UInt8 = 32
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero

    public var BYTES: [UInt64] { self.bytes }

    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }
}
