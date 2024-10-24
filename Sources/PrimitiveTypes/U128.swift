public struct U128: BigUInt {
    private let bytes: [UInt64]

    public static let numberBytes: UInt8 = 16
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero

    public var BYTES: [UInt64] { self.bytes }

    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U128 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }
}
