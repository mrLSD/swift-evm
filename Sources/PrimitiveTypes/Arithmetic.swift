extension BigUInt {
    /// Performs an overflow addition operation with the given value.
    ///
    /// - Parameter value: The value to be added.
    ///
    /// - Returns: A tuple containing the result of the addition and a boolean value indicating whether an overflow occurred.
    func overflowAdd(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: Int(Self.numberBase))
        var carry = false

        for i in 0..<Int(Self.numberBase) {
            let sum = self.BYTES[i].addingReportingOverflow(value.BYTES[i])
            let total = sum.partialValue.addingReportingOverflow(carry ? 1 : 0)

            result[i] = total.partialValue
            carry = sum.overflow || total.overflow
        }
        let overflow = carry
        return (Self(from: result), overflow)
    }

    /// Performs an overflow subtraction operation on the current value with the given value.
    ///
    /// - Parameter value: The value to subtract from the current value.
    ///
    /// - Returns: A tuple containing the result of the subtraction operation and a boolean value indicating whether an overflow occurred.
    func overflowSub(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: Int(Self.numberBase))
        var borrow: Bool = false

        for i in 0..<Int(Self.numberBase) {
            let sub = self.BYTES[i].subtractingReportingOverflow(value.BYTES[i])
            let total = sub.partialValue.subtractingReportingOverflow(borrow ? 1 : 0)
            result[i] = total.partialValue
            borrow = sub.overflow || total.overflow
        }
        let overflow = borrow
        return (Self(from: result), overflow)
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
    static func mac(_ lhs: inout UInt64, _ a: UInt64, _ b: UInt64, _ carry: UInt64) -> UInt64 {
        let (productHigh, productLow) = a.multipliedFullWidth(by: b)
        let (sumLow1, carry1) = productLow.addingReportingOverflow(carry)
        let (sumLow2, carry2) = sumLow1.addingReportingOverflow(lhs)
        lhs = sumLow2
        return productHigh &+ (carry1 ? 1 : 0) &+ (carry2 ? 1 : 0)
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
}
