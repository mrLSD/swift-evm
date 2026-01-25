/// `H160` is a fixed-size array of 20 bytes (160 bits), commonly used to represent Ethereum addresses and other similar data structures.
public struct H160: FixedArray, Hashable {
    /// Internal storage for the bytes of `H160`.
    private var bytes: [UInt8]

    /// Number of bytes in `H160`.
    public static let numberBytes: UInt8 = 20
    /// Max value of `H160`.
    public static let MAX: Self = getMax
    /// Zero value of `H160`.
    public static let ZERO: Self = getZero

    /// Bytes of the `H160` instance.
    public var BYTES: [UInt8] { bytes }

    /// Initialize `H160` from a byte array.
    public init(from bytes: [UInt8]) {
        precondition(bytes.count == Self.numberBytes, "H160 must be initialized with \(Self.numberBytes) bytes array.")
        self.bytes = bytes
    }

    /// Implement hashing for `H160`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(BYTES)
    }
}
