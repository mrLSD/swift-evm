/// Bitwise operations
public extension BigUInt {
    /// Performs a bitwise left shift (SHL)
    @inline(__always)
    func shiftLeft(_ shift: Int) -> Self {
        if shift <= 0 {
            return self
        }
        var result = [UInt64](repeating: 0, count: self.BYTES.count)
        let wordShift = shift / 64
        let bitShift = shift % 64

        // Shift
        for i in wordShift ..< self.BYTES.count {
            result[i] = self.BYTES[i - wordShift] << bitShift
        }

        // Carry
        if bitShift > 0 {
            for i in wordShift + 1 ..< self.BYTES.count {
                result[i] |= self.BYTES[i - 1 - wordShift] >> (64 - bitShift)
            }
        }
        return Self(from: result)
    }

    /// Performs a bitwise logical right shift (SHR)
    @inline(__always)
    func shiftRight(_ shift: Int) -> Self {
        if shift <= 0 {
            return self
        }
        var result = [UInt64](repeating: 0, count: self.BYTES.count)
        let wordShift = shift / 64
        let bitShift = shift % 64

        // Shift
        for i in wordShift ..< self.BYTES.count {
            result[i - wordShift] = self.BYTES[i] >> bitShift
        }

        // Carry
        if bitShift > 0 {
            for i in wordShift + 1 ..< self.BYTES.count {
                result[i - wordShift - 1] |= self.BYTES[i] << (64 - bitShift)
            }
        }
        return Self(from: result)
    }

    static func << (lhs: Self, shift: Int) -> Self {
        lhs.shiftLeft(shift)
    }

    static func >> (lhs: Self, shift: Int) -> Self {
        lhs.shiftRight(shift)
    }

    /// Logical NOT of two values of the same type.
    static prefix func ~ (lhs: Self) -> Self {
        var result = [UInt64](repeating: 0, count: lhs.BYTES.count)
        for i in 0 ..< lhs.BYTES.count {
            result[i] = ~lhs.BYTES[i]
        }
        return Self(from: result)
    }

    /// Logical AND of two values of the same type.
    static func & (lhs: Self, rhs: Self) -> Self {
        var result = [UInt64](repeating: 0, count: lhs.BYTES.count)
        for i in 0 ..< lhs.BYTES.count {
            result[i] = lhs.BYTES[i] & rhs.BYTES[i]
        }
        return Self(from: result)
    }

    /// Logical OR of two values of the same type.
    static func | (lhs: Self, rhs: Self) -> Self {
        var result = [UInt64](repeating: 0, count: lhs.BYTES.count)
        for i in 0 ..< lhs.BYTES.count {
            result[i] = lhs.BYTES[i] | rhs.BYTES[i]
        }
        return Self(from: result)
    }

    /// Logical XOR of two values of the same type.
    static func ^ (lhs: Self, rhs: Self) -> Self {
        var result = [UInt64](repeating: 0, count: lhs.BYTES.count)
        for i in 0 ..< lhs.BYTES.count {
            result[i] = lhs.BYTES[i] ^ rhs.BYTES[i]
        }
        return Self(from: result)
    }
}
