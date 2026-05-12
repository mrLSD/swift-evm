/// `I256`: signed 256-bit integer type.
///
/// Storage mirrors `U256` (four `UInt64` limbs in little-endian order) plus a `signExtend` flag
/// that indicates a negative value in two's-complement representation.
public struct I256: BigUInt {
    @usableFromInline let l0: UInt64
    @usableFromInline let l1: UInt64
    @usableFromInline let h0: UInt64
    @usableFromInline let h1: UInt64

    /// Number of bytes in `I256`.
    public static let numberBytes: UInt8 = 32
    /// Maximum value of `I256` (positive max — the bit pattern is `0xff..ff`, but here it's the all-ones representation per BigUInt contract).
    public static let MAX: Self = .init(l0: .max, l1: .max, h0: .max, h1: .max, signExtend: false)
    /// Zero value of `I256`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, h0: 0, h1: 0, signExtend: false)

    /// Sign bit mask for `I256` type (clears the sign bit).
    public static let SIGN_BIT_MASK: U256 = .init(
        l0: 0xffff_ffff_ffff_ffff,
        l1: 0xffff_ffff_ffff_ffff,
        h0: 0xffff_ffff_ffff_ffff,
        h1: 0x7fff_ffff_ffff_ffff
    )

    /// Sign extension flag: `true` if the number is negative.
    public private(set) var signExtend: Bool

    /// Computed array view (allocates).
    public var BYTES: [UInt64] {
        [l0, l1, h0, h1]
    }

    /// Direct field initializer.
    @inline(__always)
    public init(l0: UInt64, l1: UInt64, h0: UInt64, h1: UInt64, signExtend: Bool) {
        self.l0 = l0
        self.l1 = l1
        self.h0 = h0
        self.h1 = h1
        self.signExtend = signExtend
    }

    /// Initialize from `[UInt64]` with `signExtend == false`.
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "I256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.l0 = value[0]
        self.l1 = value[1]
        self.h0 = value[2]
        self.h1 = value[3]
        self.signExtend = false
    }

    /// Initialize from `[UInt64]` with explicit `signExtend` flag.
    public init(from value: [UInt64], signExtend: Bool) {
        precondition(value.count == Self.numberBase, "I256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.l0 = value[0]
        self.l1 = value[1]
        self.h0 = value[2]
        self.h1 = value[3]
        self.signExtend = signExtend
    }

    /// Create an `I256` from a `U256` value.
    public static func fromU256(_ val: U256) -> Self {
        if (val & SIGN_BIT_MASK) == val {
            return I256(l0: val.l0, l1: val.l1, h0: val.h0, h1: val.h1, signExtend: false)
        } else {
            let n = ~val + U256(from: 1)
            return I256(l0: n.l0, l1: n.l1, h0: n.h0, h1: n.h1, signExtend: true)
        }
    }

    /// Convert `I256` to `U256`.
    public var toU256: U256 {
        if signExtend {
            // ~self + 1 — but using field arithmetic keeps allocation off the critical path.
            let inv = U256(l0: ~l0, l1: ~l1, h0: ~h0, h1: ~h1)
            let one = U256(l0: 1, l1: 0, h0: 0, h1: 0)
            return inv + one
        } else {
            return U256(l0: l0, l1: l1, h0: h0, h1: h1)
        }
    }

    /// Bitwise operations. Only shifting right, as for negative number it will be Shift Arithmetic Right (SAR).
    public func shiftRight(_ shift: Int) -> Self {
        if isZero || shift >= 256 || shift < 0 {
            if signExtend {
                // value is `< 0`, pushing `-1`
                return Self(l0: 1, l1: 0, h0: 0, h1: 0, signExtend: true)
            } else {
                // value is 0 or `>= 1`, pushing 0
                return Self.ZERO
            }
        } else {
            // `Value < 0`
            if signExtend {
                let me = U256(l0: l0, l1: l1, h0: h0, h1: h1)
                let val = ((me - U256(from: 1)) >> shift) + U256(from: 1)
                return Self(l0: val.l0, l1: val.l1, h0: val.h0, h1: val.h1, signExtend: true)
            } else {
                let val = toU256 >> shift
                return Self(l0: val.l0, l1: val.l1, h0: val.h0, h1: val.h1, signExtend: false)
            }
        }
    }

    /// Minimum value of I256.
    public static let minValue: Self = {
        let mask = U256.MAX & Self.SIGN_BIT_MASK
        let v = mask + U256(from: 1)
        return .init(l0: v.l0, l1: v.l1, h0: v.h0, h1: v.h1, signExtend: true)
    }()

    /// `I256` division operation.
    func div(rhs: Self) -> Self {
        // MIN_VALUE / 1 == MIN_VALUE; MIN_VALUE / -1 also returns MIN_VALUE per Yellow Paper (EVM overflow semantics)
        // We don't check sign of rhs, because both 1 and -1 have the same bytes representation.
        if self == Self.minValue, rhs.l0 == 1, rhs.l1 == 0, rhs.h0 == 0, rhs.h1 == 0 {
            return Self.minValue
        }

        var d = divRem(divisor: rhs).quotient & I256(from: Self.SIGN_BIT_MASK.BYTES)
        if d.isZero {
            return Self.ZERO
        }

        switch (signExtend, rhs.signExtend) {
        case (true, true):
            return d
        case (false, false):
            return d
        default:
            // `positive / negative` or `negative / positive` division returns negative number.
            d.signExtend = true
            return d
        }
    }

    /// `I256` remainder operation.
    func rem(rhs: Self) -> Self {
        var r = divRem(divisor: rhs).remainder & I256(from: Self.SIGN_BIT_MASK.BYTES)
        if r.isZero {
            return Self.ZERO
        }
        r.signExtend = signExtend
        return r
    }
}

// MARK: - Equatable / Comparable (signed semantics)

public extension I256 {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.signExtend, rhs.signExtend) {
        case (true, true), (false, false):
            return lhs.l0 == rhs.l0 && lhs.l1 == rhs.l1 && lhs.h0 == rhs.h0 && lhs.h1 == rhs.h1
        case (true, false), (false, true):
            return false
        }
    }

    static func != (lhs: Self, rhs: Self) -> Bool {
        !(lhs == rhs)
    }

    /// Unsigned-style limb compare (helper for signed comparison and BigUInt fallback).
    @inlinable @inline(__always)
    static func _cmpLessUnsigned(_ a: Self, _ b: Self) -> Bool {
        if a.h1 != b.h1 { return a.h1 < b.h1 }
        if a.h0 != b.h0 { return a.h0 < b.h0 }
        if a.l1 != b.l1 { return a.l1 < b.l1 }
        return a.l0 < b.l0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.signExtend, rhs.signExtend) {
        case (true, true):
            // Both negative: larger absolute magnitude is smaller value.
            return _cmpLessUnsigned(rhs, lhs)
        case (false, false):
            return _cmpLessUnsigned(lhs, rhs)
        case (true, false):
            return true
        case (false, true):
            return false
        }
    }

    static func > (lhs: Self, rhs: Self) -> Bool {
        rhs < lhs
    }

    static func <= (lhs: Self, rhs: Self) -> Bool {
        !(lhs > rhs)
    }

    static func >= (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs)
    }

    @inlinable @inline(__always)
    var isZero: Bool {
        l0 == 0 && l1 == 0 && h0 == 0 && h1 == 0
    }
}

// MARK: - Shift operator

public extension I256 {
    static func >> (lhs: Self, shift: Int) -> Self {
        lhs.shiftRight(shift)
    }
}

// MARK: - Division / Remainder

public extension I256 {
    static func / (lhs: Self, rhs: Self) -> Self {
        lhs.div(rhs: rhs)
    }

    static func % (lhs: Self, rhs: Self) -> Self {
        lhs.rem(rhs: rhs)
    }
}
