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
    /// The Keccak-256 hash of the empty string `""`.
    public static let KECCAK_EMPTY: Self = Self(from: [
        0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
        0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
        0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
        0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70,
    ])

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
