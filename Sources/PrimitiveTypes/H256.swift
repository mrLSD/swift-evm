public struct H256: FixedArray, Hashable {
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

    /// Covert `H256` to `H160` by taking the last 20 bytes
    /// Optimizations:  only one array copy (analog of `memcpy`)
    public func toH160() -> H160 {
        return bytes.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress! + 12
            let buffer = UnsafeBufferPointer(start: base, count: 20)
            // Only one copy
            return H160(from: Array(buffer))
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(BYTES)
    }
}
