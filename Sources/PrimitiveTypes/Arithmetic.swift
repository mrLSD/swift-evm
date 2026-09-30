/// `BigUInt` arithmetic operations.
///
/// Concrete types implement the arithmetic needed by the EVM on stored fields.
/// Generic division materializes each operand once and runs Knuth on limb arrays.
extension BigUInt {
    /// Multiply-accumulate primitive: `lhs += a*b + carry`, returns the high carry.
    /// Used by per-type multiplication implementations.
    @inlinable @inline(__always)
    static func mac(_ lhs: inout UInt64, _ a: UInt64, _ b: UInt64, _ carry: UInt64) -> UInt64 {
        let (productHigh, productLow) = a.multipliedFullWidth(by: b)
        let (sumLow1, carry1) = productLow.addingReportingOverflow(carry)
        let (sumLow2, carry2) = sumLow1.addingReportingOverflow(lhs)
        lhs = sumLow2
        return productHigh &+ (carry1 ? 1 : 0) &+ (carry2 ? 1 : 0)
    }

    /// Divides unsigned magnitudes, materializing each operand once.
    /// - Precondition: `rhs` must not be zero.
    func divMod(_ rhs: Self) -> (quotient: Self, remainder: Self) {
        precondition(!rhs.isZero, "Division by zero")
        let (quotient, remainder) = Self.divMod(BYTES, rhs.BYTES)
        return (Self(from: quotient), Self(from: remainder))
    }

    /// Divides equal-width, little-endian arrays; the divisor is nonzero.
    private static func divMod(_ u: [UInt64], _ v: [UInt64]) -> (quotient: [UInt64], remainder: [UInt64]) {
        let uBits = Self.leastNumber(u)
        let vBits = Self.leastNumber(v)
        if vBits == 1 {
            return (u, [UInt64](repeating: 0, count: u.count))
        }
        // Early return in case we are dividing by a larger number than us
        if uBits < vBits {
            return ([UInt64](repeating: 0, count: u.count), u)
        }
        if vBits <= 64 {
            return Self.divModSmall(u, v[0])
        }

        // divisor limbs
        let n = 1 + (vBits - 1) / 64
        // extra dividend limbs
        let m = 1 + (uBits - 1) / 64 - n

        return Self.divModKnuth(u, v, n: n, m: m)
    }

    /// Returns the least number of bits needed to represent the number (`0` for zero).
    private static func leastNumber(_ a: [UInt64]) -> Int {
        guard let index = a.lastIndex(where: { $0 > 0 }) else {
            return 0
        }
        return 64 * (index + 1) - a[index].leadingZeroBitCount
    }

    /// Adds up to `to` limbs, returning the carry beyond the selected slice.
    static func addSlice(a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int) -> Bool {
        var carry = false
        for i in 0 ..< min(a.count - from, b.count, to) {
            let (sum, c0) = a[from + i].addingReportingOverflow(b[i])
            let (value, c1) = sum.addingReportingOverflow(carry ? 1 : 0)
            a[from + i] = value
            carry = c0 || c1
        }
        return carry
    }

    /// D6: restore the divisor after an overestimated quotient digit.
    static func carryAddSlice(carry: Bool, q_hat: inout UInt64, a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int) { // swiftlint:disable:this function_parameter_count
        if carry {
            q_hat -= 1
            let c = Self.addSlice(a: &a, from: from, b: b, to: to)
            a[from + to] = a[from + to] &+ (c ? 1 : 0)
        }
    }

    /// Divides `(hi << 64) | lo` by `y`. Requires `hi < y`, so the quotient fits in UInt64.
    static func divModWord(hi: UInt64, lo: UInt64, y: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        y.dividingFullWidth((high: hi, low: lo))
    }

    /// Subtracts q*v from n+1 dividend limbs without a temporary product.
    private static func subMul(_ u: inout [UInt64], at j: Int, _ v: [UInt64], count n: Int, by q: UInt64) -> Bool {
        var carry: UInt64 = 0
        var borrow = false
        for i in 0 ..< n {
            let (hi, lo) = v[i].multipliedFullWidth(by: q)
            let (low, overflow) = lo.addingReportingOverflow(carry)
            // A word product plus a word carry fits in two words.
            carry = hi + (overflow ? 1 : 0)
            let (difference, b0) = u[j + i].subtractingReportingOverflow(low)
            let (value, b1) = difference.subtractingReportingOverflow(borrow ? 1 : 0)
            u[j + i] = value
            borrow = b0 || b1
        }
        let (difference, b0) = u[j + n].subtractingReportingOverflow(carry)
        let (value, b1) = difference.subtractingReportingOverflow(borrow ? 1 : 0)
        u[j + n] = value
        return b0 || b1
    }

    /// `a << shift` for `0 <= shift < 64`; bits shifted out of the top limb are dropped.
    private static func shiftLeft(_ a: [UInt64], _ shift: Int) -> [UInt64] {
        var res = a.map { $0 << shift }
        if shift > 0 {
            for i in 1 ..< a.count {
                res[i] |= a[i - 1] >> (64 - shift)
            }
        }
        return res
    }

    /// `a >> shift` for `0 <= shift < 64`, narrowed by one limb (the top limb is always zero here).
    private static func shiftRight(_ a: [UInt64], _ shift: Int) -> [UInt64] {
        var res = (0 ..< a.count - 1).map { a[$0] >> shift }
        if shift > 0 {
            for i in 0 ..< res.count {
                res[i] |= a[i + 1] << (64 - shift)
            }
        }
        return res
    }

    /// Division and modulus by a single limb.
    private static func divModSmall(_ u: [UInt64], _ d: UInt64) -> (quotient: [UInt64], remainder: [UInt64]) {
        var rem: UInt64 = 0
        var quotient = [UInt64](repeating: 0, count: u.count)
        for i in stride(from: u.count - 1, through: 0, by: -1) {
            let (q, r) = Self.divModWord(hi: rem, lo: u[i], y: d)
            quotient[i] = q
            rem = r
        }
        var remainder = [UInt64](repeating: 0, count: u.count)
        remainder[0] = rem
        return (quotient, remainder)
    }

    /// See Knuth, TAOCP, Volume 2, section 4.3.1, Algorithm D.
    /// `n` is the number of divisor limbs, `m` the number of extra dividend limbs.
    private static func divModKnuth(_ u0: [UInt64], _ v0: [UInt64], n: Int, m: Int) -> (quotient: [UInt64], remainder: [UInt64]) {
        // D1.
        // Make sure 64th bit in v's highest word is set.
        // If we shift both u and v, it won't affect the quotient
        // and the remainder will only need to be shifted back.
        let shift = v0[n - 1].leadingZeroBitCount
        let v = Self.shiftLeft(v0, shift)

        // u will store the remainder (shifted); one extra limb holds the bits shifted out.
        var u = Self.shiftLeft(u0 + [0], shift)

        // quotient
        var q = [UInt64](repeating: 0, count: u0.count)
        let v_n_1 = v[n - 1]
        let v_n_2 = v[n - 2]

        // D2. D7.
        // iterate from m downto 0
        for j in stride(from: m, through: 0, by: -1) {
            let u_jn = u[j + n]

            // D3.
            // q_hat is our guess for the j-th quotient digit
            // q_hat = min(b - 1, (u_{j+n} * b + u_{j+n-1}) / v_{n-1})
            // b = 1 << WORD_BITS
            // Theorem B: q_hat >= q_j >= q_hat - 2
            var q_hat: UInt64
            if u_jn < v_n_1 {
                var (temp_q_hat, r_hat) = Self.divModWord(hi: u_jn, lo: u[j + n - 1], y: v_n_1)
                // this loop takes at most 2 iterations
                while true {
                    // Check if q_hat * v_n_2 > b * r_hat + u[j+n-2]
                    let (hi, lo) = temp_q_hat.multipliedFullWidth(by: v_n_2)
                    if (hi, lo) <= (r_hat, u[j + n - 2]) {
                        break
                    }
                    // then iterate till it doesn't hold
                    temp_q_hat -= 1
                    let (new_r_hat, overflow) = r_hat.addingReportingOverflow(v_n_1)
                    r_hat = new_r_hat
                    // if r_hat overflowed, we're done
                    if overflow {
                        break
                    }
                }
                q_hat = temp_q_hat
            } else {
                // here q_hat >= q_j >= q_hat - 1
                q_hat = UInt64.max
            }

            // ex. 20:
            // since q_hat * v_{n-2} <= b * r_hat + u_{j+n-2},
            // either q_hat == q_j, or q_hat == q_j + 1

            // D4.
            // let's assume optimistically q_hat == q_j
            // subtract (q_hat * v) from u[j..]
            let c = Self.subMul(&u, at: j, v, count: n, by: q_hat)

            // D6.
            // Actually, q_hat == q_j + 1 and u[j..] has overflowed
            // Highly unlikely ~ (1 / 2^63)
            //
            // Add v to u[j..<j + n]
            Self.carryAddSlice(carry: c, q_hat: &q_hat, a: &u, from: j, b: v, to: n)

            // D5.
            q[j] = q_hat
        }

        // D8.
        return (q, Self.shiftRight(u, shift))
    }

    /// Returns the unsigned quotient and remainder. The divisor must be nonzero.
    @inline(__always)
    public func divRem(divisor: Self) -> (quotient: Self, remainder: Self) {
        self.divMod(divisor)
    }
}
