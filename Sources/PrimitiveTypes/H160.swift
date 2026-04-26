/// `H160` is a fixed-size 20-byte value, commonly used to represent Ethereum addresses.
///
/// Storage is fixed-size value layout (`l0: UInt64`, `l1: UInt64`, `l2: UInt32`) — exactly 20 bytes
/// inline, no heap allocation per instance. Hashing is auto-synthesized over these three fields,
/// avoiding the per-byte `Array` traversal of the previous `[UInt8]` storage. The public
/// `BYTES: [UInt8]` accessor is preserved as a computed view for `FixedArray` protocol
/// compatibility.
public struct H160: FixedArray, Hashable {
    /// Bytes 0..7 (most-significant first when serialized big-endian).
    @usableFromInline let l0: UInt64
    /// Bytes 8..15.
    @usableFromInline let l1: UInt64
    /// Bytes 16..19.
    @usableFromInline let l2: UInt32

    /// Number of bytes in `H160`.
    public static let numberBytes: UInt8 = 20
    /// Max value of `H160`.
    public static let MAX: Self = .init(l0: .max, l1: .max, l2: .max)
    /// Zero value of `H160`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, l2: 0)

    /// Computed byte view (allocates 20 bytes). Prefer field access in hot paths.
    public var BYTES: [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(20)
        // l0 (bytes 0..7), big-endian within the limb.
        out.append(UInt8(truncatingIfNeeded: l0 >> 56))
        out.append(UInt8(truncatingIfNeeded: l0 >> 48))
        out.append(UInt8(truncatingIfNeeded: l0 >> 40))
        out.append(UInt8(truncatingIfNeeded: l0 >> 32))
        out.append(UInt8(truncatingIfNeeded: l0 >> 24))
        out.append(UInt8(truncatingIfNeeded: l0 >> 16))
        out.append(UInt8(truncatingIfNeeded: l0 >> 8))
        out.append(UInt8(truncatingIfNeeded: l0))
        // l1 (bytes 8..15).
        out.append(UInt8(truncatingIfNeeded: l1 >> 56))
        out.append(UInt8(truncatingIfNeeded: l1 >> 48))
        out.append(UInt8(truncatingIfNeeded: l1 >> 40))
        out.append(UInt8(truncatingIfNeeded: l1 >> 32))
        out.append(UInt8(truncatingIfNeeded: l1 >> 24))
        out.append(UInt8(truncatingIfNeeded: l1 >> 16))
        out.append(UInt8(truncatingIfNeeded: l1 >> 8))
        out.append(UInt8(truncatingIfNeeded: l1))
        // l2 (bytes 16..19, only the low 32 bits).
        out.append(UInt8(truncatingIfNeeded: l2 >> 24))
        out.append(UInt8(truncatingIfNeeded: l2 >> 16))
        out.append(UInt8(truncatingIfNeeded: l2 >> 8))
        out.append(UInt8(truncatingIfNeeded: l2))
        return out
    }

    /// Direct field initializer (no allocation).
    @inlinable @inline(__always)
    public init(l0: UInt64, l1: UInt64, l2: UInt32) {
        self.l0 = l0
        self.l1 = l1
        self.l2 = l2
    }

    /// Initialize `H160` from a 20-byte big-endian byte array.
    public init(from bytes: [UInt8]) {
        precondition(bytes.count == Int(Self.numberBytes), "H160 must be initialized with \(Self.numberBytes) bytes array.")
        // Pack bytes 0..7 into l0 (big-endian within the limb).
        self.l0 =
            (UInt64(bytes[0]) << 56) |
            (UInt64(bytes[1]) << 48) |
            (UInt64(bytes[2]) << 40) |
            (UInt64(bytes[3]) << 32) |
            (UInt64(bytes[4]) << 24) |
            (UInt64(bytes[5]) << 16) |
            (UInt64(bytes[6]) << 8) |
            UInt64(bytes[7])
        // Bytes 8..15 into l1.
        self.l1 =
            (UInt64(bytes[8]) << 56) |
            (UInt64(bytes[9]) << 48) |
            (UInt64(bytes[10]) << 40) |
            (UInt64(bytes[11]) << 32) |
            (UInt64(bytes[12]) << 24) |
            (UInt64(bytes[13]) << 16) |
            (UInt64(bytes[14]) << 8) |
            UInt64(bytes[15])
        // Bytes 16..19 into l2.
        self.l2 =
            (UInt32(bytes[16]) << 24) |
            (UInt32(bytes[17]) << 16) |
            (UInt32(bytes[18]) << 8) |
            UInt32(bytes[19])
    }
}
