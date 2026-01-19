/// `U512` is an unsigned 512-bit integer type.
public struct U512: BigUInt {
    /// Internal representation as an array of  `UInt64` values.
    private let bytes: [UInt64]

    /// Number of bytes used to represent `U256`.
    public static let numberBytes: UInt8 = 64
    /// Maximum value of `U512`
    public static let MAX: Self = getMax
    /// Zero value of `U512`
    public static let ZERO: Self = getZero

    /// Bytes of `U512`.
    public var BYTES: [UInt64] { self.bytes }

    /// Initializer from an array of `UInt64` values.
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U512 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }

    /// Initializer from `U256`, with leading zeros.
    public init(from value: U256) {
        let limbs = value.BYTES
        self.bytes = [limbs[0], limbs[1], limbs[2], limbs[3], 0, 0, 0, 0]
    }
}
