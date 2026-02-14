/// `H256` is a fixed-size array of 32 bytes, commonly used to represent hashes in blockchain applications.
public struct H256: FixedArray, Hashable {
    /// Internal bytes storage
    private var bytes: [UInt8]

    /// Number of bytes in H256
    public static let numberBytes: UInt8 = 32
    /// Max value of H256
    public static let MAX: Self = getMax
    /// Zero value of H256
    public static let ZERO: Self = getZero

    /// Bytes of H256
    public var BYTES: [UInt8] { bytes }

    /// Initializer from bytes array
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

    /// Convert `H256` to `H160` by taking the last 20 bytes
    /// Optimizations:  only one array copy (analog of `memcpy`)
    public func toH160() -> H160 {
        return bytes.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress! + 12
            let buffer = UnsafeBufferPointer(start: base, count: 20)
            // Only one copy
            return H160(from: Array(buffer))
        }
    }

    /// Hashable conformance of H256
    public func hash(into hasher: inout Hasher) {
        hasher.combine(BYTES)
    }
}
