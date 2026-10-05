/// `U256` is a 256-bit unsigned integer represented as four `UInt64` limbs in little-endian order.
///
/// Storage is fixed-size value layout (`l0`, `l1`, `h0`, `h1`) — no heap allocation per instance.
/// Hot arithmetic operates directly on these fields. `BYTES` is provided as a computed accessor for
/// the `BigUInt` protocol contract.
public struct U256: BigUInt {
    /// Limb 0 (bits 0..63).
    @usableFromInline let l0: UInt64
    /// Limb 1 (bits 64..127).
    @usableFromInline let l1: UInt64
    /// Limb 2 (bits 128..191).
    @usableFromInline let h0: UInt64
    /// Limb 3 (bits 192..255).
    @usableFromInline let h1: UInt64

    /// Number of bytes used to represent `U256`.
    public static let numberBytes: UInt8 = 32
    /// Maximum value of `U256`.
    public static let MAX: Self = .init(l0: .max, l1: .max, h0: .max, h1: .max)
    /// Zero value of `U256`.
    public static let ZERO: Self = .init(l0: 0, l1: 0, h0: 0, h1: 0)

    /// Computed array view (allocates). Prefer field access in hot paths.
    public var BYTES: [UInt64] {
        [l0, l1, h0, h1]
    }

    /// Direct field initializer (no allocation).
    @inlinable @inline(__always)
    public init(l0: UInt64, l1: UInt64, h0: UInt64, h1: UInt64) {
        self.l0 = l0
        self.l1 = l1
        self.h0 = h0
        self.h1 = h1
    }

    /// Initializes one limb without an array conversion.
    @inlinable @inline(__always)
    public init(from value: UInt64) {
        self.init(l0: value, l1: 0, h0: 0, h1: 0)
    }

    /// Keeps the low 256 bits of a full-width EVM intermediate.
    @inlinable @inline(__always)
    public init(truncating value: U512) {
        self.init(l0: value.l0, l1: value.l1, h0: value.l2, h1: value.l3)
    }

    /// Interprets a hash as a big-endian EVM word.
    @inlinable @inline(__always)
    public init(from value: H256) {
        self.init(l0: value.l3, l1: value.l2, h0: value.l1, h1: value.l0)
    }

    /// Array initializer (validates length).
    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.l0 = value[0]
        self.l1 = value[1]
        self.h0 = value[2]
        self.h1 = value[3]
    }
}

// MARK: - Integer accessors / Endianness (specialized — bypass BYTES allocation)

public extension U256 {
    /// Get `UInt` value from `U256` (or `nil` if value does not fit).
    /// On 64-bit systems always succeeds when the upper three limbs are zero.
    @inlinable @inline(__always)
    var getUInt: UInt? {
        guard l1 == 0, h0 == 0, h1 == 0 else { return nil }
        return UInt(exactly: l0)
    }

    /// Get `Int` value from `U256` (or `nil` if value does not fit).
    @inlinable @inline(__always)
    var getInt: Int? {
        guard l1 == 0, h0 == 0, h1 == 0 else { return nil }
        return Int(exactly: l0)
    }

    /// Converts an EVM offset to Int without materializing limbs.
    @inlinable @inline(__always)
    var saturatingInt: Int {
        getInt ?? Int.max
    }

    /// Number of leading zero bits; `256` for zero.
    @inlinable @inline(__always)
    var leadingZeroBitCount: Int {
        if h1 != 0 { return h1.leadingZeroBitCount }
        if h0 != 0 { return 64 + h0.leadingZeroBitCount }
        if l1 != 0 { return 128 + l1.leadingZeroBitCount }
        return 192 + l0.leadingZeroBitCount
    }

    /// Big-endian byte representation (32 bytes, MSB first).
    var toBigEndian: [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(32)
        for limb in [h1, h0, l1, l0] {
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

    /// Writes exactly 32 bytes; the destination need not be aligned.
    @inlinable
    func writeBigEndian(to buffer: UnsafeMutableRawBufferPointer) {
        precondition(buffer.count == 32, "U256 requires a 32-byte destination.")
        var words = (h1.bigEndian, h0.bigEndian, l1.bigEndian, l0.bigEndian)
        withUnsafeBytes(of: &words) { buffer.copyMemory(from: $0) }
    }

    /// Reads up to 32 big-endian bytes, with leading zero padding and no alignment requirement.
    init(bigEndian bytes: UnsafeRawBufferPointer) {
        precondition(bytes.count <= 32, "BigUInt must be initialized with not more than 32 bytes.")
        if bytes.count == 32 {
            self.init(
                l0: UInt64(bigEndian: bytes.loadUnaligned(fromByteOffset: 24, as: UInt64.self)),
                l1: UInt64(bigEndian: bytes.loadUnaligned(fromByteOffset: 16, as: UInt64.self)),
                h0: UInt64(bigEndian: bytes.loadUnaligned(fromByteOffset: 8, as: UInt64.self)),
                h1: UInt64(bigEndian: bytes.loadUnaligned(as: UInt64.self))
            )
            return
        }
        var l0: UInt64 = 0, l1: UInt64 = 0, h0: UInt64 = 0, h1: UInt64 = 0
        for i in 0 ..< bytes.count {
            let value = UInt64(bytes[bytes.count - 1 - i]) << ((i % 8) * 8)
            switch i / 8 {
            case 0: l0 |= value
            case 1: l1 |= value
            case 2: h0 |= value
            default: h1 |= value
            }
        }
        self.init(l0: l0, l1: l1, h0: h0, h1: h1)
    }

    /// Reads at most 32 bytes, padding shorter input on the left.
    static func fromBigEndian(from val: [UInt8]) -> U256 {
        val.withUnsafeBytes { U256(bigEndian: $0) }
    }
}

// MARK: - Equality / Comparison

public extension U256 {
    @inlinable @inline(__always)
    static func == (lhs: U256, rhs: U256) -> Bool {
        lhs.l0 == rhs.l0 && lhs.l1 == rhs.l1 && lhs.h0 == rhs.h0 && lhs.h1 == rhs.h1
    }

    @inlinable @inline(__always)
    static func != (lhs: U256, rhs: U256) -> Bool {
        !(lhs == rhs)
    }

    @inlinable @inline(__always)
    static func < (lhs: U256, rhs: U256) -> Bool {
        // Small-value fast-path: both operands fit in the low limb (top 3 limbs zero).
        // Common in EVM (offsets, indices, gas costs, small balances).
        if (lhs.l1 | lhs.h0 | lhs.h1 | rhs.l1 | rhs.h0 | rhs.h1) == 0 {
            return lhs.l0 < rhs.l0
        }
        if lhs.h1 != rhs.h1 {
            return lhs.h1 < rhs.h1
        }
        if lhs.h0 != rhs.h0 {
            return lhs.h0 < rhs.h0
        }
        if lhs.l1 != rhs.l1 {
            return lhs.l1 < rhs.l1
        }
        return lhs.l0 < rhs.l0
    }

    @inlinable @inline(__always)
    static func > (lhs: U256, rhs: U256) -> Bool {
        rhs < lhs
    }

    @inlinable @inline(__always)
    static func <= (lhs: U256, rhs: U256) -> Bool {
        !(lhs > rhs)
    }

    @inlinable @inline(__always)
    static func >= (lhs: U256, rhs: U256) -> Bool {
        !(lhs < rhs)
    }

    @inlinable @inline(__always)
    var isZero: Bool {
        l0 == 0 && l1 == 0 && h0 == 0 && h1 == 0
    }
}

// MARK: - Arithmetic (specialized, no array allocation)

public extension U256 {
    /// Addition with overflow flag (full-width 256-bit add).
    @inlinable @inline(__always)
    func overflowAdd(_ value: U256) -> (U256, Bool) {
        // Small-value fast-path: both operands fit in the low limb. A u64+u64 sum is at most
        // (2^64-1)*2 < 2^65, so the U256 result always fits in the lower two limbs and the
        // U256-level overflow flag is always false.
        if (l1 | h0 | h1 | value.l1 | value.h0 | value.h1) == 0 {
            let (s, ovf) = l0.addingReportingOverflow(value.l0)
            return (U256(l0: s, l1: ovf ? 1 : 0, h0: 0, h1: 0), false)
        }
        let (s0, c0) = l0.addingReportingOverflow(value.l0)
        let (s1a, c1a) = l1.addingReportingOverflow(value.l1)
        let (s1, c1b) = s1a.addingReportingOverflow(c0 ? 1 : 0)
        let (s2a, c2a) = h0.addingReportingOverflow(value.h0)
        let (s2, c2b) = s2a.addingReportingOverflow((c1a || c1b) ? 1 : 0)
        let (s3a, c3a) = h1.addingReportingOverflow(value.h1)
        let (s3, c3b) = s3a.addingReportingOverflow((c2a || c2b) ? 1 : 0)
        return (U256(l0: s0, l1: s1, h0: s2, h1: s3), c3a || c3b)
    }

    /// Subtraction with borrow flag.
    @inlinable @inline(__always)
    func overflowSub(_ value: U256) -> (U256, Bool) {
        let (d0, b0) = l0.subtractingReportingOverflow(value.l0)
        let (d1a, b1a) = l1.subtractingReportingOverflow(value.l1)
        let (d1, b1b) = d1a.subtractingReportingOverflow(b0 ? 1 : 0)
        let (d2a, b2a) = h0.subtractingReportingOverflow(value.h0)
        let (d2, b2b) = d2a.subtractingReportingOverflow((b1a || b1b) ? 1 : 0)
        let (d3a, b3a) = h1.subtractingReportingOverflow(value.h1)
        let (d3, b3b) = d3a.subtractingReportingOverflow((b2a || b2b) ? 1 : 0)
        return (U256(l0: d0, l1: d1, h0: d2, h1: d3), b3a || b3b)
    }

    /// Multiplication producing the low 256 bits without overflow detection.
    /// Schoolbook 4×4 = 16-product accumulation, dropping limbs ≥ 4.
    @inline(__always)
    func mul(_ value: U256) -> U256 {
        // Accumulator limbs r0..r3.
        var r0: UInt64 = 0, r1: UInt64 = 0, r2: UInt64 = 0, r3: UInt64 = 0
        var carry: UInt64

        // i = 0: products fall into limbs 0..3.
        carry = 0
        carry = U256.mac(&r0, l0, value.l0, carry)
        carry = U256.mac(&r1, l0, value.l1, carry)
        carry = U256.mac(&r2, l0, value.h0, carry)
        _ = U256.mac(&r3, l0, value.h1, carry)
        // i = 1: products fall into limbs 1..3.
        carry = 0
        carry = U256.mac(&r1, l1, value.l0, carry)
        carry = U256.mac(&r2, l1, value.l1, carry)
        _ = U256.mac(&r3, l1, value.h0, carry)
        // i = 2: products fall into limbs 2..3.
        carry = 0
        carry = U256.mac(&r2, h0, value.l0, carry)
        _ = U256.mac(&r3, h0, value.l1, carry)
        // i = 3: only limb 3.
        _ = U256.mac(&r3, h1, value.l0, 0)

        return U256(l0: r0, l1: r1, h0: r2, h1: r3)
    }

    /// Exact 256-by-256 product for EVM modular arithmetic.
    @inlinable @inline(__always)
    func fullMul(_ value: U256) -> U512 {
        var r0: UInt64 = 0, r1: UInt64 = 0, r2: UInt64 = 0, r3: UInt64 = 0
        var r4: UInt64 = 0, r5: UInt64 = 0, r6: UInt64 = 0, r7: UInt64 = 0
        var carry: UInt64

        carry = 0
        carry = U256.mac(&r0, l0, value.l0, carry)
        carry = U256.mac(&r1, l0, value.l1, carry)
        carry = U256.mac(&r2, l0, value.h0, carry)
        carry = U256.mac(&r3, l0, value.h1, carry)
        r4 = carry

        carry = 0
        carry = U256.mac(&r1, l1, value.l0, carry)
        carry = U256.mac(&r2, l1, value.l1, carry)
        carry = U256.mac(&r3, l1, value.h0, carry)
        carry = U256.mac(&r4, l1, value.h1, carry)
        r5 = carry

        carry = 0
        carry = U256.mac(&r2, h0, value.l0, carry)
        carry = U256.mac(&r3, h0, value.l1, carry)
        carry = U256.mac(&r4, h0, value.h0, carry)
        carry = U256.mac(&r5, h0, value.h1, carry)
        r6 = carry

        carry = 0
        carry = U256.mac(&r3, h1, value.l0, carry)
        carry = U256.mac(&r4, h1, value.l1, carry)
        carry = U256.mac(&r5, h1, value.h0, carry)
        carry = U256.mac(&r6, h1, value.h1, carry)
        r7 = carry

        return U512(l0: r0, l1: r1, l2: r2, l3: r3, h0: r4, h1: r5, h2: r6, h3: r7)
    }

    /// Low 256 bits and a flag indicating nonzero high bits.
    @inline(__always)
    func overflowMul(_ value: U256) -> (U256, Bool) {
        let product = fullMul(value)
        return (U256(truncating: product), (product.h0 | product.h1 | product.h2 | product.h3) != 0)
    }

    @inlinable @inline(__always)
    static func + (lhs: U256, rhs: U256) -> U256 {
        lhs.overflowAdd(rhs).0
    }

    @inlinable @inline(__always)
    static func - (lhs: U256, rhs: U256) -> U256 {
        lhs.overflowSub(rhs).0
    }

    @inlinable @inline(__always)
    static func * (lhs: U256, rhs: U256) -> U256 {
        lhs.mul(rhs)
    }

    @inlinable @inline(__always)
    static func += (lhs: inout U256, rhs: U256) {
        lhs = lhs + rhs
    }

    @inlinable @inline(__always)
    static func -= (lhs: inout U256, rhs: U256) {
        lhs = lhs - rhs
    }

    @inlinable @inline(__always)
    static func *= (lhs: inout U256, rhs: U256) {
        lhs = lhs * rhs
    }
}

// MARK: - Bitwise / Shift

public extension U256 {
    @inlinable @inline(__always)
    static prefix func ~ (lhs: U256) -> U256 {
        U256(l0: ~lhs.l0, l1: ~lhs.l1, h0: ~lhs.h0, h1: ~lhs.h1)
    }

    @inlinable @inline(__always)
    static func & (lhs: U256, rhs: U256) -> U256 {
        U256(l0: lhs.l0 & rhs.l0, l1: lhs.l1 & rhs.l1, h0: lhs.h0 & rhs.h0, h1: lhs.h1 & rhs.h1)
    }

    @inlinable @inline(__always)
    static func | (lhs: U256, rhs: U256) -> U256 {
        U256(l0: lhs.l0 | rhs.l0, l1: lhs.l1 | rhs.l1, h0: lhs.h0 | rhs.h0, h1: lhs.h1 | rhs.h1)
    }

    @inlinable @inline(__always)
    static func ^ (lhs: U256, rhs: U256) -> U256 {
        U256(l0: lhs.l0 ^ rhs.l0, l1: lhs.l1 ^ rhs.l1, h0: lhs.h0 ^ rhs.h0, h1: lhs.h1 ^ rhs.h1)
    }

    /// Logical left shift.
    @inline(__always)
    func shiftLeft(_ shift: Int) -> U256 {
        if shift <= 0 {
            return self
        }
        if shift >= 256 {
            return .ZERO
        }
        let wordShift = shift / 64
        let bitShift = shift % 64

        // Source limbs at indices [0,1,2,3].
        let src0: UInt64 = l0
        let src1: UInt64 = l1
        let src2: UInt64 = h0
        let src3: UInt64 = h1

        var d0: UInt64 = 0, d1: UInt64 = 0, d2: UInt64 = 0, d3: UInt64 = 0

        // wordShift is in 0..3 (because shift < 256 has been validated above).
        // Place src[i] at d[i + wordShift] (if within bounds).
        if wordShift == 0 {
            d0 = src0; d1 = src1; d2 = src2; d3 = src3
        } else if wordShift == 1 {
            d1 = src0; d2 = src1; d3 = src2
        } else if wordShift == 2 {
            d2 = src0; d3 = src1
        } else {
            d3 = src0
        }

        if bitShift == 0 {
            return U256(l0: d0, l1: d1, h0: d2, h1: d3)
        }

        let n = UInt64(bitShift)
        let inv = 64 - n
        // Apply bit shift with carry from the lower limb.
        let r3 = (d3 << n) | (d2 >> inv)
        let r2 = (d2 << n) | (d1 >> inv)
        let r1 = (d1 << n) | (d0 >> inv)
        let r0 = d0 << n
        return U256(l0: r0, l1: r1, h0: r2, h1: r3)
    }

    /// Logical right shift.
    @inline(__always)
    func shiftRight(_ shift: Int) -> U256 {
        if shift <= 0 {
            return self
        }
        if shift >= 256 {
            return .ZERO
        }
        let wordShift = shift / 64
        let bitShift = shift % 64

        let src0: UInt64 = l0
        let src1: UInt64 = l1
        let src2: UInt64 = h0
        let src3: UInt64 = h1

        var d0: UInt64 = 0, d1: UInt64 = 0, d2: UInt64 = 0, d3: UInt64 = 0

        // wordShift is in 0..3.
        // Place src[i] at d[i - wordShift] (if non-negative).
        if wordShift == 0 {
            d0 = src0; d1 = src1; d2 = src2; d3 = src3
        } else if wordShift == 1 {
            d0 = src1; d1 = src2; d2 = src3
        } else if wordShift == 2 {
            d0 = src2; d1 = src3
        } else {
            d0 = src3
        }

        if bitShift == 0 {
            return U256(l0: d0, l1: d1, h0: d2, h1: d3)
        }

        let n = UInt64(bitShift)
        let inv = 64 - n
        let r0 = (d0 >> n) | (d1 << inv)
        let r1 = (d1 >> n) | (d2 << inv)
        let r2 = (d2 >> n) | (d3 << inv)
        let r3 = d3 >> n
        return U256(l0: r0, l1: r1, h0: r2, h1: r3)
    }

    @inlinable @inline(__always)
    static func << (lhs: U256, shift: Int) -> U256 {
        lhs.shiftLeft(shift)
    }

    @inlinable @inline(__always)
    static func >> (lhs: U256, shift: Int) -> U256 {
        lhs.shiftRight(shift)
    }
}

// MARK: - Division (fast paths on stored fields)

public extension U256 {
    /// Returns quotient and remainder, using stored fields for small divisors and quotient one.
    /// - Precondition: `divisor` must not be zero.
    func divRem(divisor: U256) -> (quotient: U256, remainder: U256) {
        precondition(!divisor.isZero, "Division by zero")
        if self < divisor {
            return (.ZERO, self)
        }
        if (divisor.l1 | divisor.h0 | divisor.h1) == 0 {
            return divRem(word: divisor.l0)
        }
        // self >= divisor; a remainder below divisor proves the quotient is one.
        let remainder = self - divisor
        if remainder < divisor {
            return (U256(from: 1), remainder)
        }
        return divMod(divisor)
    }

    /// Division by a single limb: four chained full-width word divisions, no arrays.
    private func divRem(word d: UInt64) -> (quotient: U256, remainder: U256) {
        let (q3, r3) = d.dividingFullWidth((high: 0, low: h1))
        let (q2, r2) = d.dividingFullWidth((high: r3, low: h0))
        let (q1, r1) = d.dividingFullWidth((high: r2, low: l1))
        let (q0, r0) = d.dividingFullWidth((high: r1, low: l0))
        return (U256(l0: q0, l1: q1, h0: q2, h1: q3), U256(from: r0))
    }

    static func / (lhs: U256, rhs: U256) -> U256 {
        lhs.divRem(divisor: rhs).quotient
    }

    static func % (lhs: U256, rhs: U256) -> U256 {
        lhs.divRem(divisor: rhs).remainder
    }

    static func /= (lhs: inout U256, rhs: U256) {
        lhs = lhs / rhs
    }

    static func %= (lhs: inout U256, rhs: U256) {
        lhs = lhs % rhs
    }
}
