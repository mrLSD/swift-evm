/// Bitwise operations
public extension BigUInt {
    /// Performs a bitwise left shift (SHL)
    @inline(__always)
    func shiftLeftForBytes(_ shift: Int) -> Self {
        if shift <= 0 {
            return self
        }
        if shift >= Int(Self.numberBytes) * 8 {
            return Self.ZERO
        }
        let words = BYTES
        var result = [UInt64](repeating: 0, count: words.count)
        let wordShift = shift / 64
        let bitShift = shift % 64

        // Shift
        for i in wordShift ..< words.count {
            result[i] = words[i - wordShift] << bitShift
        }

        // Carry
        if bitShift > 0 {
            for i in wordShift + 1 ..< words.count {
                result[i] |= words[i - 1 - wordShift] >> (64 - bitShift)
            }
        }
        return Self(from: result)
    }

    /// Performs a bitwise logical right shift (SHR)
    @inline(__always)
    func shiftRightForBytes(_ shift: Int) -> Self {
        if shift <= 0 {
            return self
        }
        if shift >= Int(Self.numberBytes) * 8 {
            return Self.ZERO
        }
        let words = BYTES
        var result = [UInt64](repeating: 0, count: words.count)
        let wordShift = shift / 64
        let bitShift = shift % 64

        // Shift
        for i in wordShift ..< words.count {
            result[i - wordShift] = words[i] >> bitShift
        }

        // Carry
        if bitShift > 0 {
            for i in wordShift + 1 ..< words.count {
                result[i - wordShift - 1] |= words[i] << (64 - bitShift)
            }
        }
        return Self(from: result)
    }
}
