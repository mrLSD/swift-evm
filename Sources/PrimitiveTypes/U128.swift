/// `U128` is a 128-bit unsigned integer type represented using two `UInt64` values.
public struct U128: BigUInt {
    /// Internal constant representing the number of `UInt64` values used to represent `U128`.
    private let bytes: [UInt64]

    /// Number of bytes in `U128`.
    public static let numberBytes: UInt8 = 16
    /// Maximum value of `U128`.
    public static let MAX: Self = getMax
    /// Zero value of U128
    public static let ZERO: Self = getZero

    /// Bytes of U128
    public var BYTES: [UInt64] { self.bytes }

    /// Initializer from an array of `UInt64` values.
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U128 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }
}
