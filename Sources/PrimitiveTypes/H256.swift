/// `H256` is a fixed-size 32-byte value, commonly used to represent hashes in blockchain applications.
///
/// Storage is fixed-size value layout (`l0..l3: UInt64`) — 32 bytes inline, no heap allocation per
/// instance. Hashing is auto-synthesized over the four limb fields. The public `BYTES: [UInt8]`
/// accessor is preserved as a computed view for `FixedArray` protocol compatibility.
public struct H256: FixedArray, Hashable {
    /// Bytes 0..7 (most-significant first when serialized big-endian).
    @usableFromInline let l0: UInt64
    /// Bytes 8..15.
    @usableFromInline let l1: UInt64
    /// Bytes 16..23.
    @usableFromInline let l2: UInt64
    /// Bytes 24..31.
    @usableFromInline let l3: UInt64

    /// Number of bytes in `H256`.
    public static let numberBytes: UInt8 = 32
    /// Max value of `H256`.
    public static let MAX: Self = .init(l0: .max, l1: .max, l2: .max, l3: .max)
    /// Zero value of `H256`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, l2: 0, l3: 0)

    /// Computed byte view (allocates 32 bytes).
    public var BYTES: [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(32)
        for limb in [l0, l1, l2, l3] {
            out.append(UInt8(truncatingIfNeeded: limb >> 56))
            out.append(UInt8(truncatingIfNeeded: limb >> 48))
            out.append(UInt8(truncatingIfNeeded: limb >> 40))
            out.append(UInt8(truncatingIfNeeded: limb >> 32))
            out.append(UInt8(truncatingIfNeeded: limb >> 24))
            out.append(UInt8(truncatingIfNeeded: limb >> 16))
            out.append(UInt8(truncatingIfNeeded: limb >> 8))
            out.append(UInt8(truncatingIfNeeded: limb))
        }
        return out
    }

    /// Direct field initializer (no allocation).
    @inlinable @inline(__always)
    public init(l0: UInt64, l1: UInt64, l2: UInt64, l3: UInt64) {
        self.l0 = l0
        self.l1 = l1
        self.l2 = l2
        self.l3 = l3
    }

    /// Initialize `H256` from a 32-byte big-endian byte array.
    public init(from bytes: [UInt8]) {
        precondition(bytes.count == Int(Self.numberBytes), "H256 must be initialized with \(Self.numberBytes) bytes array.")
        self.l0 =
            (UInt64(bytes[0]) << 56) |
            (UInt64(bytes[1]) << 48) |
            (UInt64(bytes[2]) << 40) |
            (UInt64(bytes[3]) << 32) |
            (UInt64(bytes[4]) << 24) |
            (UInt64(bytes[5]) << 16) |
            (UInt64(bytes[6]) << 8) |
            UInt64(bytes[7])
        self.l1 =
            (UInt64(bytes[8]) << 56) |
            (UInt64(bytes[9]) << 48) |
            (UInt64(bytes[10]) << 40) |
            (UInt64(bytes[11]) << 32) |
            (UInt64(bytes[12]) << 24) |
            (UInt64(bytes[13]) << 16) |
            (UInt64(bytes[14]) << 8) |
            UInt64(bytes[15])
        self.l2 =
            (UInt64(bytes[16]) << 56) |
            (UInt64(bytes[17]) << 48) |
            (UInt64(bytes[18]) << 40) |
            (UInt64(bytes[19]) << 32) |
            (UInt64(bytes[20]) << 24) |
            (UInt64(bytes[21]) << 16) |
            (UInt64(bytes[22]) << 8) |
            UInt64(bytes[23])
        self.l3 =
            (UInt64(bytes[24]) << 56) |
            (UInt64(bytes[25]) << 48) |
            (UInt64(bytes[26]) << 40) |
            (UInt64(bytes[27]) << 32) |
            (UInt64(bytes[28]) << 24) |
            (UInt64(bytes[29]) << 16) |
            (UInt64(bytes[30]) << 8) |
            UInt64(bytes[31])
    }

    /// Init from `H160` with 12-byte leading zero pad (left).
    /// `H256[0..11] = 0`, `H256[12..31] = H160[0..19]`.
    @inlinable @inline(__always)
    public init(from value: H160) {
        // First 8 bytes of H256 (l0) are all zero.
        self.l0 = 0
        // l1 corresponds to bytes 8..15 of H256:
        //   bytes 8..11 are zero (the remaining 4 bytes of leading zero pad);
        //   bytes 12..15 of H256 = bytes 0..3 of H160 = top 32 bits of value.l0.
        self.l1 = value.l0 >> 32
        // l2 (bytes 16..23 of H256) = bytes 4..11 of H160 =
        //   low 32 bits of value.l0 (high half of l2) and top 32 bits of value.l1 (low half of l2).
        self.l2 = (value.l0 << 32) | (value.l1 >> 32)
        // l3 (bytes 24..31 of H256) = bytes 12..19 of H160 =
        //   low 32 bits of value.l1 (high half of l3) and value.l2 (low half of l3).
        self.l3 = (value.l1 << 32) | UInt64(value.l2)
    }

    /// Convert `H256` to `H160` by taking the last 20 bytes.
    @inlinable @inline(__always)
    public func toH160() -> H160 {
        // Bytes 12..19 of H256 = top 32 bits of l1 (high half) and low 32 bits of l1 (low half) → H160.l0.
        let h0 = (l1 << 32) | (l2 >> 32)
        // Bytes 20..27 of H256 = low 32 bits of l2 (high half) and top 32 bits of l3 (low half) → H160.l1.
        let h1 = (l2 << 32) | (l3 >> 32)
        // Bytes 28..31 of H256 = low 32 bits of l3 → H160.l2.
        let h2 = UInt32(truncatingIfNeeded: l3)
        return H160(l0: h0, l1: h1, l2: h2)
    }
}
