/// `U512` is a 512-bit unsigned integer represented as eight `UInt64` limbs in little-endian order.
///
/// Storage is fixed-size value layout (`l0`..`l3` / `h0`..`h3`) — no heap allocation per instance.
/// EVM uses `U512` only for `ADDMOD`/`MULMOD` intermediate results (`+`, `*`, `%`), so only those
/// hot paths are specialized. Rare operations fall back to the generic `BigUInt` extension.
public struct U512: BigUInt {
    @usableFromInline let l0: UInt64
    @usableFromInline let l1: UInt64
    @usableFromInline let l2: UInt64
    @usableFromInline let l3: UInt64
    @usableFromInline let h0: UInt64
    @usableFromInline let h1: UInt64
    @usableFromInline let h2: UInt64
    @usableFromInline let h3: UInt64

    /// Number of bytes used to represent `U512`.
    public static let numberBytes: UInt8 = 64
    /// Maximum value of `U512`.
    public static let MAX: Self = .init(l0: .max, l1: .max, l2: .max, l3: .max, h0: .max, h1: .max, h2: .max, h3: .max)
    /// Zero value of `U512`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, l2: 0, l3: 0, h0: 0, h1: 0, h2: 0, h3: 0)

    /// Computed array view (allocates). Prefer field access in hot paths.
    public var BYTES: [UInt64] {
        [l0, l1, l2, l3, h0, h1, h2, h3]
    }

    /// Direct field initializer (no allocation).
    @inlinable @inline(__always)
    public init(l0: UInt64, l1: UInt64, l2: UInt64, l3: UInt64,
                h0: UInt64, h1: UInt64, h2: UInt64, h3: UInt64)
    {
        self.l0 = l0
        self.l1 = l1
        self.l2 = l2
        self.l3 = l3
        self.h0 = h0
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
    }

    /// Array initializer (validates length).
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U512 must be initialized with \(Self.numberBase) UInt64 values.")
        self.l0 = value[0]
        self.l1 = value[1]
        self.l2 = value[2]
        self.l3 = value[3]
        self.h0 = value[4]
        self.h1 = value[5]
        self.h2 = value[6]
        self.h3 = value[7]
    }

    /// Initializer from `U256`, with leading zeros.
    @inlinable @inline(__always)
    public init(from value: U256) {
        self.l0 = value.l0
        self.l1 = value.l1
        self.l2 = value.h0
        self.l3 = value.h1
        self.h0 = 0
        self.h1 = 0
        self.h2 = 0
        self.h3 = 0
    }
}

// MARK: - Equality / Comparison (specialized)

public extension U512 {
    @inlinable @inline(__always)
    static func == (lhs: U512, rhs: U512) -> Bool {
        lhs.l0 == rhs.l0 && lhs.l1 == rhs.l1 && lhs.l2 == rhs.l2 && lhs.l3 == rhs.l3 &&
            lhs.h0 == rhs.h0 && lhs.h1 == rhs.h1 && lhs.h2 == rhs.h2 && lhs.h3 == rhs.h3
    }

    @inlinable @inline(__always)
    static func != (lhs: U512, rhs: U512) -> Bool {
        !(lhs == rhs)
    }

    @inlinable @inline(__always)
    static func < (lhs: U512, rhs: U512) -> Bool {
        if lhs.h3 != rhs.h3 { return lhs.h3 < rhs.h3 }
        if lhs.h2 != rhs.h2 { return lhs.h2 < rhs.h2 }
        if lhs.h1 != rhs.h1 { return lhs.h1 < rhs.h1 }
        if lhs.h0 != rhs.h0 { return lhs.h0 < rhs.h0 }
        if lhs.l3 != rhs.l3 { return lhs.l3 < rhs.l3 }
        if lhs.l2 != rhs.l2 { return lhs.l2 < rhs.l2 }
        if lhs.l1 != rhs.l1 { return lhs.l1 < rhs.l1 }
        return lhs.l0 < rhs.l0
    }

    @inlinable @inline(__always)
    static func > (lhs: U512, rhs: U512) -> Bool {
        rhs < lhs
    }

    @inlinable @inline(__always)
    static func <= (lhs: U512, rhs: U512) -> Bool {
        !(lhs > rhs)
    }

    @inlinable @inline(__always)
    static func >= (lhs: U512, rhs: U512) -> Bool {
        !(lhs < rhs)
    }

    @inlinable @inline(__always)
    var isZero: Bool {
        (l0 | l1 | l2 | l3 | h0 | h1 | h2 | h3) == 0
    }
}

// MARK: - Arithmetic (specialized; only `+` and `*` are exercised on hot paths)

public extension U512 {
    /// Helper that adds `b` to `a` with incoming carry, returning `(a+b+carry, carryOut)`.
    @inlinable @inline(__always)
    static func _adc(_ a: UInt64, _ b: UInt64, _ carry: Bool) -> (UInt64, Bool) {
        let (s1, c1) = a.addingReportingOverflow(b)
        let (s2, c2) = s1.addingReportingOverflow(carry ? 1 : 0)
        return (s2, c1 || c2)
    }

    /// Addition with overflow flag (full-width 512-bit add).
    @inline(__always)
    func overflowAdd(_ value: U512) -> (U512, Bool) {
        let (s0, c0) = U512._adc(l0, value.l0, false)
        let (s1, c1) = U512._adc(l1, value.l1, c0)
        let (s2, c2) = U512._adc(l2, value.l2, c1)
        let (s3, c3) = U512._adc(l3, value.l3, c2)
        let (s4, c4) = U512._adc(h0, value.h0, c3)
        let (s5, c5) = U512._adc(h1, value.h1, c4)
        let (s6, c6) = U512._adc(h2, value.h2, c5)
        let (s7, c7) = U512._adc(h3, value.h3, c6)
        return (U512(l0: s0, l1: s1, l2: s2, l3: s3, h0: s4, h1: s5, h2: s6, h3: s7), c7)
    }

    /// Multiplication producing the low 512 bits without overflow detection.
    @inline(__always)
    func mul(_ value: U512) -> U512 {
        // 8x8 schoolbook, dropping limbs >= 8.
        var r = (UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0))
        let a = (l0, l1, l2, l3, h0, h1, h2, h3)
        let b = (value.l0, value.l1, value.l2, value.l3, value.h0, value.h1, value.h2, value.h3)
        var carry: UInt64

        // i=0
        carry = 0
        carry = U512.mac(&r.0, a.0, b.0, carry)
        carry = U512.mac(&r.1, a.0, b.1, carry)
        carry = U512.mac(&r.2, a.0, b.2, carry)
        carry = U512.mac(&r.3, a.0, b.3, carry)
        carry = U512.mac(&r.4, a.0, b.4, carry)
        carry = U512.mac(&r.5, a.0, b.5, carry)
        carry = U512.mac(&r.6, a.0, b.6, carry)
        _ = U512.mac(&r.7, a.0, b.7, carry)
        // i=1
        carry = 0
        carry = U512.mac(&r.1, a.1, b.0, carry)
        carry = U512.mac(&r.2, a.1, b.1, carry)
        carry = U512.mac(&r.3, a.1, b.2, carry)
        carry = U512.mac(&r.4, a.1, b.3, carry)
        carry = U512.mac(&r.5, a.1, b.4, carry)
        carry = U512.mac(&r.6, a.1, b.5, carry)
        _ = U512.mac(&r.7, a.1, b.6, carry)
        // i=2
        carry = 0
        carry = U512.mac(&r.2, a.2, b.0, carry)
        carry = U512.mac(&r.3, a.2, b.1, carry)
        carry = U512.mac(&r.4, a.2, b.2, carry)
        carry = U512.mac(&r.5, a.2, b.3, carry)
        carry = U512.mac(&r.6, a.2, b.4, carry)
        _ = U512.mac(&r.7, a.2, b.5, carry)
        // i=3
        carry = 0
        carry = U512.mac(&r.3, a.3, b.0, carry)
        carry = U512.mac(&r.4, a.3, b.1, carry)
        carry = U512.mac(&r.5, a.3, b.2, carry)
        carry = U512.mac(&r.6, a.3, b.3, carry)
        _ = U512.mac(&r.7, a.3, b.4, carry)
        // i=4
        carry = 0
        carry = U512.mac(&r.4, a.4, b.0, carry)
        carry = U512.mac(&r.5, a.4, b.1, carry)
        carry = U512.mac(&r.6, a.4, b.2, carry)
        _ = U512.mac(&r.7, a.4, b.3, carry)
        // i=5
        carry = 0
        carry = U512.mac(&r.5, a.5, b.0, carry)
        carry = U512.mac(&r.6, a.5, b.1, carry)
        _ = U512.mac(&r.7, a.5, b.2, carry)
        // i=6
        carry = 0
        carry = U512.mac(&r.6, a.6, b.0, carry)
        _ = U512.mac(&r.7, a.6, b.1, carry)
        // i=7
        _ = U512.mac(&r.7, a.7, b.0, 0)

        return U512(l0: r.0, l1: r.1, l2: r.2, l3: r.3, h0: r.4, h1: r.5, h2: r.6, h3: r.7)
    }

    @inlinable @inline(__always)
    static func + (lhs: U512, rhs: U512) -> U512 {
        lhs.overflowAdd(rhs).0
    }

    @inlinable @inline(__always)
    static func * (lhs: U512, rhs: U512) -> U512 {
        lhs.mul(rhs)
    }
}
