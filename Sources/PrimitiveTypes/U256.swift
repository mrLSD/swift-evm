/// `U256` is a 256-bit unsigned integer type.
public struct U256: BigUInt {
    /// Internal representation as an array of  `UInt64` values.
    private let bytes: [UInt64]

    /// Number of bytes used to represent `U256`.
    public static let numberBytes: UInt8 = 32
    /// Maximum value of `U256`.
    public static let MAX: Self = getMax
    /// Zero value of `U256`.
    public static let ZERO: Self = getZero

    /// Bytes of `U256`.
    public var BYTES: [UInt64] { self.bytes }

    /// Initializer from an array of `UInt64` values.
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }
}
