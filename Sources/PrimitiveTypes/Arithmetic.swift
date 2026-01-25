/// `BigUInt` arithmetic operations.
public extension BigUInt {
    /// Performs an overflow addition operation with the given value.
    ///
    /// - Parameter value: The value to be added.
    ///
    /// - Returns: A tuple containing the result of the addition and a boolean value indicating whether an overflow occurred.
    func overflowAdd(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: self.BYTES.count)
        var carry = false

        for i in 0 ..< self.BYTES.count {
            let sum = self.BYTES[i].addingReportingOverflow(value.BYTES[i])
            let total = sum.partialValue.addingReportingOverflow(carry ? 1 : 0)

            result[i] = total.partialValue
            carry = sum.overflow || total.overflow
        }
        let isOverflow = carry
        return (Self(from: result), isOverflow)
    }

    /// Performs an overflow subtraction operation on the current value with the given value.
    ///
    /// - Parameter value: The value to subtract from the current value.
    ///
    /// - Returns: A tuple containing the result of the subtraction operation and a boolean value indicating whether an overflow occurred.
    func overflowSub(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: self.BYTES.count)
        var borrow = false

        for i in 0 ..< self.BYTES.count {
            let sub = self.BYTES[i].subtractingReportingOverflow(value.BYTES[i])
            let total = sub.partialValue.subtractingReportingOverflow(borrow ? 1 : 0)
            result[i] = total.partialValue
            borrow = sub.overflow || total.overflow
        }
        let isOverflow = borrow
        return (Self(from: result), isOverflow)
    }

    /// Performs an overflow multiplication operation with the given value.
    ///
    /// Algorithm based on `mac` (multiply-accumulate) operation. It's optimised to avoid
    /// redundant operations with matrix. In common cases multiplication is `2*Width`. For
    /// 256-bit, in common cases result will be 512-bit - `high` and `low` part. `Low` contains
    /// result itself, `high` contains overflowed number. We've optimised the algorithm to return only `Width`,
    /// itself, to avoid redundant calculations, and just calculating `overflow` flag.
    ///
    /// - Parameter value: The value to be multiplying.
    ///
    /// - Returns: A tuple containing the result of the operation and a boolean value indicating whether an overflow occurred.
    @inline(__always)
    func overflowMul(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: 2 * self.BYTES.count)

        // Matrix multiplication
        for i in 0 ..< self.BYTES.count {
            var carry: UInt64 = 0
            for j in 0 ..< self.BYTES.count {
                carry = Self.mac(&result[i + j], self.BYTES[i], value.BYTES[j], carry)
            }
            result[i + self.BYTES.count] = carry
        }
        let isOverflow = result[self.BYTES.count ..< 2 * self.BYTES.count].contains { $0 != 0 }
        let lowResult = Array(result[0 ..< self.BYTES.count])
        return (Self(from: lowResult), isOverflow)
    }

    /// Performs multiplication operation with the given value without overflow check.
    ///
    /// Algorithm base on `mac` (multiply-accumulate) operation. It's optimised to avoid
    /// redundant operations with matrix. In common cases multiplication `2*Width`. For
    /// 256-bit in common cases result will be 512-bit - `high` and `low` part. `Low` contains
    /// result itself, `high` contains overflowed number. We're optimized algorithm to return only `Width`,
    /// itself, to avoid redundant calculations, but for that we can't correctly calculate overflow status (for that
    /// we should perform full multiplication).
    ///
    /// - Parameter value: The value to be multiplying.
    ///
    /// - Returns: The result of the multiplication (overflow is discarded).
    @inline(__always)
    func mul(_ value: Self) -> Self {
        var result = [UInt64](repeating: 0, count: self.BYTES.count)

        // Matrix multiplication
        for i in 0 ..< self.BYTES.count {
            var carry: UInt64 = 0
            // Restrict multiplication operations to `Self.numberBase` and carry overflow status.
            for j in 0 ... (self.BYTES.count - 1 - i) {
                carry = Self.mac(&result[i + j], self.BYTES[i], value.BYTES[j], carry)
            }
        }
        return Self(from: result)
    }

    ///  Calculates the multiply-accumulate operation.
    ///
    ///  - Parameters:
    ///     - lhs: The left-hand side value to be updated with the result.
    ///     - a: The first operand of the multiplication.
    ///     - b: The second operand of the multiplication.
    ///     - carry: The carry value to be added.
    ///
    ///  - Returns: The result of the multiply-accumulate operation.
    @inline(__always)
    internal static func mac(_ lhs: inout UInt64, _ a: UInt64, _ b: UInt64, _ carry: UInt64) -> UInt64 {
        let (productHigh, productLow) = a.multipliedFullWidth(by: b)
        let (sumLow1, carry1) = productLow.addingReportingOverflow(carry)
        let (sumLow2, carry2) = sumLow1.addingReportingOverflow(lhs)
        lhs = sumLow2
        return productHigh &+ (carry1 ? 1 : 0) &+ (carry2 ? 1 : 0)
    }

    /// Returns the least number of bits needed to represent the number
    private func leastNumber() -> Int {
        guard let index = BYTES.lastIndex(where: { $0 > 0 }) else {
            return 0
        }
        return (0x40 * (index + 1)) - BYTES[index].leadingZeroBitCount
    }

    /// Returns the least number of words needed to represent the nonzero number
    private func leastNumberOfWords(bits: Int) -> Int {
        1 + (bits - 1) / 64
    }

    /// Computes the quotient and remainder of dividing this value by `rhs`.
    ///
    /// - Parameter rhs: The divisor.
    /// - Returns: A tuple containing:
    ///   - quotient: The integer quotient of `self / rhs`.
    ///   - remainder: The remainder of `self % rhs`.
    /// - Precondition: `rhs` must not be zero.
    /// - Note: If `rhs == 1`, returns `(self, .ZERO)`.
    /// - Note: If `rhs` is larger than `self`, returns `(.ZERO, self)`.
    /// - Note: Uses a small-word division path when `rhs` fits in `UInt64`, otherwise falls back to Knuth’s long division.
    func divMod(_ rhs: Self) -> (quotient: Self, remainder: Self) {
        precondition(!rhs.isZero, "Division by zero")
        if rhs == Self(from: 1) {
            return (self, Self.ZERO)
        }

        let lhsLeastNumber = self.leastNumber()
        let rhsLeastNumber = rhs.leastNumber()

        // Early return in case we are dividing by a larger number than us
        if lhsLeastNumber < rhsLeastNumber {
            return (Self.ZERO, self)
        }

        if rhsLeastNumber <= 64 {
            return self.divModSmall(other: rhs.BYTES[0])
        }

        let lhsWord = self.leastNumberOfWords(bits: lhsLeastNumber)
        let rhsWord = self.leastNumberOfWords(bits: rhsLeastNumber)
        var rhs = rhs
        return self.divModKnuth(v: &rhs, n: rhsWord, m: lhsWord - rhsWord)
    }

    /// Adds two slices of UInt64 and updates the first slice.
    /// - Parameters:
    ///   - a: The first slice to be mutated.
    ///   - b: The second slice to be added.
    /// - Returns: A boolean indicating whether there was an overflow.
    static func addSlice(a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int) -> Bool {
        self.binopSlice(a: &a, from: from, b: b, to: to, binop: { x, y in x.addingReportingOverflow(y) })
    }

    /// Add v to u[j..<j + n]
    static func carryAddSlice(carry: Bool, q_hat: inout UInt64, a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int) { // // swiftlint:disable:this function_parameter_count
        if carry {
            q_hat -= 1
            let c = Self.addSlice(a: &a, from: from, b: b, to: to)
            a[from + to] = a[from + to] &+ (c ? 1 : 0)
        }
    }

    /// Subtracts the second slice from the first slice.
    /// - Parameters:
    ///   - a: The first slice to be mutated.
    ///   - b: The second slice to be subtracted.
    /// - Returns: A boolean indicating whether there was a borrow.
    static func subSlice(a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int) -> Bool {
        self.binopSlice(a: &a, from: from, b: b, to: to, binop: { x, y in x.subtractingReportingOverflow(y) })
    }

    /// Performs a binary operation on two slices of UInt64.
    ///
    /// It performs `zip` operation for to arrays.
    /// Intersection of two ranges without going beyond each range for arrays.
    ///
    /// - Parameters:
    ///   - a: The first slice to be mutated.
    ///   - b: The second slice.
    ///   - binop: A binary operation that takes two UInt64s and returns a tuple of (result, overflow).
    /// - Returns: A boolean indicating whether there was an overflow.
    private static func binopSlice(a: inout [UInt64], from: Int, b: borrowing [UInt64], to: Int, binop: (UInt64, UInt64) -> (UInt64, Bool)) -> Bool {
        var carry = false
        // Check correct range for zip operation.
        let endIndex = min(a.count - from, b.count, to)
        // Perform zip operation and calculations. The range.
        // Intersection of two ranges without going beyond each range for arrays.
        for i in 0 ..< endIndex {
            let (result, c) = Self.binopCarry(a[from + i], b[i], carry, binop)
            a[from + i] = result
            carry = c
        }
        return carry
    }

    /// Performs a binary operation with carry.
    private static func binopCarry(_ a: UInt64, _ b: UInt64, _ c: Bool, _ binop: (UInt64, UInt64) -> (UInt64, Bool)) -> (UInt64, Bool) {
        let (res1, overflow1) = b.addingReportingOverflow(c ? 1 : 0)
        let (res2, overflow2) = binop(a, res1)
        return (res2, overflow1 || overflow2)
    }

    /// Returns the quotient and remainder of dividing a 128-bit number (hi << 64 + lo) by a 64-bit y.
    /// Assumes that `hi < y`.
    static func divModWord(hi: UInt64, lo: UInt64, y: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        DivModUtils.divModWord(hi: hi, lo: lo, y: y)
    }

    /// Multiply UInt64 with carry
    private static func mulUInt64(_ a: UInt64, _ b: UInt64, _ carry: UInt64) -> (UInt64, UInt64) {
        let res = (U128(from: a) * U128(from: b)) + U128(from: carry)
        return (res.BYTES[0], res.BYTES[1])
    }

    /// Overflowing multiplication by Uint64.
    /// Returns the result and carry.
    private func overflowMulUInt64(by value: UInt64) -> (Self, UInt64) {
        var carry: UInt64 = 0
        var result = [UInt64](repeating: 0, count: self.BYTES.count)
        for i in 0 ..< self.BYTES.count {
            let (res, c) = Self.mulUInt64(self.BYTES[i], value, carry)
            result[i] = res
            carry = c
        }
        return (Self(from: result), carry)
    }

    /// Full multiplication by UInt64.
    private func fullMulUInt64(by: UInt64) -> [UInt64] {
        var res = [UInt64](repeating: 0, count: self.BYTES.count + 1)
        let (prod, carry) = self.overflowMulUInt64(by: by)
        res.replaceSubrange(0 ..< self.BYTES.count, with: prod.BYTES)
        res[self.BYTES.count] = carry
        return res
    }

    /// Full shift right of an array of UInt64 by `shift` bits.
    private static func fullShr(_ u: borrowing [UInt64], _ shift: Int) -> Self {
        let n_words = u.count - 1
        var resWords = [UInt64](repeating: 0, count: n_words)

        for i in 0 ..< n_words {
            resWords[i] = u[i] >> shift
        }
        if shift > 0 {
            for i in 1 ... n_words {
                resWords[i - 1] |= u[i] << (64 - shift)
            }
        }

        return Self(from: resWords)
    }

    /// Division and modulus by small UInt64 number.
    private func divModSmall(other: UInt64) -> (quotient: Self, remainder: Self) {
        var rem: UInt64 = 0
        var quotient = [UInt64](repeating: 0, count: self.BYTES.count)
        for i in stride(from: quotient.count - 1, through: 0, by: -1) {
            let (q, r) = Self.divModWord(hi: rem, lo: self.BYTES[i], y: other)
            quotient[i] = q
            rem = r
        }

        return (Self(from: quotient), Self(from: rem))
    }

    /// See Knuth, TAOCP, Volume 2, section 4.3.1, Algorithm D.
    func divModKnuth(v: inout Self, n: Int, m: Int) -> (quotient: Self, remainder: Self) {
        // D1.
        // Make sure 64th bit in v's highest word is set.
        // If we shift both self and v, it won't affect the quotient
        // and the remainder will only need to be shifted back.
        let shift = v.BYTES[n - 1].leadingZeroBitCount
        v = v << shift

        // u will store the remainder (shifted)
        var u = [UInt64](repeating: 0, count: self.BYTES.count + 1)
        let u_lo = self.BYTES[0] << shift
        let u_hi = self >> (64 - shift)
        u[0] = u_lo
        u.replaceSubrange(1 ..< u.count, with: u_hi.BYTES)

        // quotient
        var q = [UInt64](repeating: 0, count: self.BYTES.count)
        let v_n_1 = v.BYTES[n - 1]
        let v_n_2 = v.BYTES[n - 2]

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
                    let product = U128(from: temp_q_hat) * U128(from: v_n_2)
                    let (lo, hi) = (product.BYTES[0], product.BYTES[1])
                    if (hi, lo) <= (r_hat, u[j + n - 2]) {
                        break
                    }
                    // then iterate till it doesn't hold
                    temp_q_hat -= 1
                    let (new_r_hat, overflow) = r_hat.addingReportingOverflow(v_n_1)
                    r_hat = new_r_hat
                    // if r_hat overflowed, we're done
                    if overflow { break }
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
            let q_hat_v = v.fullMulUInt64(by: q_hat)
            // u[j..] -= q_hat_v;
            let c = Self.subSlice(a: &u, from: j, b: q_hat_v, to: n + 1)

            // D6.
            // Actually, q_hat == q_j + 1 and u[j..] has overflowed
            // Highly unlikely ~ (1 / 2^63)
            //
            // Add v to u[j..<j + n]
            Self.carryAddSlice(carry: c, q_hat: &q_hat, a: &u, from: j, b: v.BYTES, to: n)

            // D5.
            q[j] = q_hat
        }

        // D8.
        let remainder = Self.fullShr(u, shift)

        return (Self(from: q), remainder)
    }

    /// Performs an optimized long division of a fixed-bit unsigned integer by another fixed-bit unsigned integer with same length.
    ///
    /// This function divides a fixed-bit numerator by a fixed-bit divisor, both represented as arrays of four `UInt64` values
    /// (little-endian order), and returns the quotient and remainder as arrays of `UInt64`.
    ///
    /// - Parameters:
    ///   - self: An array of four `UInt64` values representing the fixed-bit numerator (dividend),
    ///   - divisor: An array of four `UInt64` values representing the fixed-bit divisor, with same length to `self`.
    ///
    /// - Returns: A tuple containing:
    ///   - `quotient`: An array of four `UInt64` values representing the fixed-bit quotient of the `division`.
    ///   - `remainder`: An array of four `UInt64` values representing the fixed-bit `remainder` after the division.
    ///
    /// - Precondition:
    ///   - The `divisor` must not be zero.
    ///   - Both `self` and `divisor` arrays must have exactly same length of elements.
    ///
    /// - Note:
    ///   - The function operates on little-endian representations of the numbers. Ensure that the least significant word is at index `0`
    ///     and the most significant word is at index `Count-1`.
    ///
    /// - Complexity: O(1), since it operates on fixed-size arrays.
    @inline(__always)
    func divRem(divisor: Self) -> (quotient: Self, remainder: Self) {
        self.divMod(divisor)
    }

    /// Adds two values of the same type together and returns the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be added.
    ///   - rhs: The right-hand side value to be added.
    ///
    /// - Returns: The sum of the two values.
    static func + (lhs: Self, rhs: Self) -> Self {
        let (result, _) = lhs.overflowAdd(rhs)
        return result
    }

    /// Performs `addition` and updates the left-hand side with the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be modified.
    ///   - rhs: The right-hand side value to be operated.
    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    /// Subtracts two values of the same type.
    ///
    /// - Parameters:
    ///   - lhs: The value to subtract from.
    ///   - rhs: The value to subtract.
    ///
    /// - Returns: The result of subtracting `rhs` from `lhs`.
    static func - (lhs: Self, rhs: Self) -> Self {
        let (result, _) = lhs.overflowSub(rhs)
        return result
    }

    /// Performs subtraction and updates the left-hand side with the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be modified.
    ///   - rhs: The right-hand side value to be operated.
    static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }

    /// Multiply two values of the same type.
    ///
    ///   - lhs: The left-hand side value to be multiplied.
    ///   - rhs: The right-hand side value to be multiplied.
    ///
    /// - Returns: The multiply of the two values.
    static func * (lhs: Self, rhs: Self) -> Self {
        lhs.mul(rhs)
    }

    /// Performs `multiply` and updates the left-hand side with the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be modified.
    ///   - rhs: The right-hand side value to be operated.
    static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }

    /// Division of two values of the same type.
    ///
    ///   - lhs: The left-hand side value to be div.
    ///   - rhs: The right-hand side value to be div.
    ///
    /// - Returns: The division of the two values.
    static func / (lhs: Self, rhs: Self) -> Self {
        let (result, _) = lhs.divRem(divisor: rhs)
        return result
    }

    /// Performs `div` and updates the left-hand side with the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be modified.
    ///   - rhs: The right-hand side value to be operated.
    static func /= (lhs: inout Self, rhs: Self) {
        lhs = lhs / rhs
    }

    /// Remainder of two values of the same type.
    static func % (lhs: Self, rhs: Self) -> Self {
        let (_, result) = lhs.divRem(divisor: rhs)
        return result
    }

    /// Performs `rem` and updates the left-hand side with the result.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to be modified.
    ///   - rhs: The right-hand side value to be operated.
    static func %= (lhs: inout Self, rhs: Self) {
        lhs = lhs % rhs
    }
}
