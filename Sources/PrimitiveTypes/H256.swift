public struct H256: FixedArray {
    private var bytes: [UInt8]

    public static let numberBytes: UInt8 = 32
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero

    public var BYTES: [UInt8] { bytes }

    public init(from bytes: [UInt8]) {
        precondition(bytes.count == Self.numberBytes, "H256 must be initialized with \(Self.numberBytes) bytes array.")
        self.bytes = bytes
    }

    /// Init from `H160` with leading zero
    public init(from value: H160) {
        var newArray = [UInt8](repeating: 0, count: 32)
        newArray.replaceSubrange(12 ..< 32, with: value.BYTES)
        self.bytes = newArray
    }
}
