/// `H256` is a fixed-size 32-byte value, commonly used to represent hashes in blockchain applications.
///
/// Storage is fixed-size value layout (`l0..l3: UInt64`) — 32 bytes inline, no heap allocation per
/// instance.
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
    /// The Keccak-256 hash of the empty string `""`.
    public static let KECCAK_EMPTY: Self = .init(from: [
        0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c,
        0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
        0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b,
        0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70,
    ])
    /// Max value of `H256`.
    public static let MAX: Self = .init(l0: .max, l1: .max, l2: .max, l3: .max)
    /// Zero value of `H256`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, l2: 0, l3: 0)

    /// Computed byte view (allocates 32 bytes). Limbs unrolled to avoid the temporary array literal.
    public var BYTES: [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(32)

        func appendBE(_ limb: UInt64) {
            out.append(UInt8(truncatingIfNeeded: limb >> 56))
            out.append(UInt8(truncatingIfNeeded: limb >> 48))
            out.append(UInt8(truncatingIfNeeded: limb >> 40))
            out.append(UInt8(truncatingIfNeeded: limb >> 32))
            out.append(UInt8(truncatingIfNeeded: limb >> 24))
            out.append(UInt8(truncatingIfNeeded: limb >> 16))
            out.append(UInt8(truncatingIfNeeded: limb >> 8))
            out.append(UInt8(truncatingIfNeeded: limb))
        }

        appendBE(l0)
        appendBE(l1)
        appendBE(l2)
        appendBE(l3)

        return out
    }

    /// Equality on stored fields. Kept explicit to make the no-allocation comparison obvious
    /// and to keep dictionary lookup hot paths predictable.
    @inlinable @inline(__always)
    public static func == (lhs: H256, rhs: H256) -> Bool {
        lhs.l0 == rhs.l0 && lhs.l1 == rhs.l1 && lhs.l2 == rhs.l2 && lhs.l3 == rhs.l3
    }

    /// Zero check on stored fields — no `BYTES` array allocation.
    @inlinable @inline(__always)
    public var isZero: Bool {
        l0 == 0 && l1 == 0 && l2 == 0 && l3 == 0
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
        // Bytes 12..19 of H256 = low 32 bits of l1 (high half of h0) and high 32 bits of l2 (low half of h0) -> H160.l0.
        let h0 = (l1 << 32) | (l2 >> 32)
        // Bytes 20..27 of H256 = low 32 bits of l2 (high half) and top 32 bits of l3 (low half) -> H160.l1.
        let h1 = (l2 << 32) | (l3 >> 32)
        // Bytes 28..31 of H256 = low 32 bits of l3 -> H160.l2.
        let h2 = UInt32(truncatingIfNeeded: l3)
        return H160(l0: h0, l1: h1, l2: h2)
    }
}
