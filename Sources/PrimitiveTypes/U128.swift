/// `U128` is a 128-bit unsigned integer type represented as two `UInt64` limbs in little-endian order.
///
/// Storage is fixed-size value layout (`l0`, `h0`) — no heap allocation per instance. The hot
/// internal uses of `U128` are multiply-accumulate (`Arithmetic.mulUInt64`) and Knuth division
/// (`q_hat * v_n_2` correction): for these, specialized `+`, `*`, `==`, `<`, `isZero` operate
/// directly on fields. Rare operations fall back to the generic `BigUInt` extension.
public struct U128: BigUInt {
    /// Low limb (bits 0..63).
    @usableFromInline let l0: UInt64
    /// High limb (bits 64..127).
    @usableFromInline let h0: UInt64

    /// Number of bytes in `U128`.
    public static let numberBytes: UInt8 = 16
    /// Maximum value of `U128`.
    public static let MAX: Self = .init(l0: .max, h0: .max)
    /// Zero value of `U128`.
    public static let ZERO: Self = .init(l0: 0, h0: 0)

    /// Computed array view (allocates). Prefer field access in hot paths.
    public var BYTES: [UInt64] {
        [l0, h0]
    }

    /// Direct field initializer (no allocation).
    @inlinable @inline(__always)
    public init(l0: UInt64, h0: UInt64) {
        self.l0 = l0
        self.h0 = h0
    }

    /// Array initializer (validates length).
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U128 must be initialized with \(Self.numberBase) UInt64 values.")
        self.l0 = value[0]
        self.h0 = value[1]
    }
}

// MARK: - Equality / Comparison (specialized)

public extension U128 {
    @inlinable @inline(__always)
    static func == (lhs: U128, rhs: U128) -> Bool {
        lhs.l0 == rhs.l0 && lhs.h0 == rhs.h0
    }

    @inlinable @inline(__always)
    var isZero: Bool {
        l0 == 0 && h0 == 0
    }
}

// MARK: - Arithmetic (specialized; only `+` and `*` are exercised on hot paths)

public extension U128 {
    /// Addition with overflow flag (full-width 128-bit add).
    @inlinable @inline(__always)
    func overflowAdd(_ value: U128) -> (U128, Bool) {
        let (s0, c0) = l0.addingReportingOverflow(value.l0)
        let (s1a, c1a) = h0.addingReportingOverflow(value.h0)
        let (s1, c1b) = s1a.addingReportingOverflow(c0 ? 1 : 0)
        return (U128(l0: s0, h0: s1), c1a || c1b)
    }

    /// Multiplication producing the low 128 bits without overflow detection.
    /// Full 256-bit product reduced mod 2^128: contributions to bits 128+ are dropped.
    @inlinable @inline(__always)
    func mul(_ value: U128) -> U128 {
        let (p00h, p00l) = l0.multipliedFullWidth(by: value.l0)
        // High limb: p00h + l0*h0 (low) + h0*l0 (low). h0*h0 wraps out.
        let r1 = p00h &+ (l0 &* value.h0) &+ (h0 &* value.l0)
        return U128(l0: p00l, h0: r1)
    }

    @inlinable @inline(__always)
    static func + (lhs: U128, rhs: U128) -> U128 {
        lhs.overflowAdd(rhs).0
    }

    @inlinable @inline(__always)
    static func * (lhs: U128, rhs: U128) -> U128 {
        lhs.mul(rhs)
    }
}
