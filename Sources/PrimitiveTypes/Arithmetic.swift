extension BigUInt {
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

    func overflowSub(_ value: Self) -> (Self, Bool) {
        var result = [UInt64](repeating: 0, count: Int(Self.numberBase))
        var borrow: UInt64 = 0
        var overflow = false

        for i in 0..<Int(Self.numberBase) {
            let (sub1, overflow1) = self.BYTES[i].subtractingReportingOverflow(value.BYTES[i])
            let (sub2, overflow2) = sub1.subtractingReportingOverflow(borrow)
            result[i] = sub2
            borrow = overflow1 ? 1 : 0
            borrow += overflow2 ? 1 : 0

            if i == Int(Self.numberBase) - 1, overflow1 || overflow2 {
                overflow = true
            }
        }

        return (Self(from: result), overflow)
    }

    func bit(at index: Int) -> Bool {
        let word = index / 64
        let bit = index % 64
        guard word < self.BYTES.count else { return false }
        return (self.BYTES[word] & (1 << bit)) != 0
    }

    func setBit(at index: Int) -> Self {
        var newBytes = self.BYTES
        let word = index / 64
        let bit = index % 64
        if word < newBytes.count {
            newBytes[word] |= (1 << bit)
        }
        return Self(from: newBytes)
    }

    static func <<(lhs: Self, rhs: Int) -> Self {
        var result = lhs.BYTES
        let wordShift = rhs / 64
        let bitShift = rhs % 64

        if wordShift >= Int(Self.numberBase) {
            return Self.ZERO
        }

        if bitShift == 0 {
            result = Array(result[wordShift..<Int(Self.numberBase)] + [UInt64](repeating: 0, count: wordShift))
        } else {
            var carry: UInt64 = 0
            for i in 0..<Int(Self.numberBase) {
                if i + wordShift >= Int(Self.numberBase) {
                    result[i] = 0
                } else {
                    let shifted = (result[i + wordShift] << bitShift) | carry
                    carry = (bitShift < 64) ? (result[i + wordShift] >> (64 - bitShift)) : 0
                    result[i] = shifted
                }
            }
        }

        return Self(from: result)
    }

    static func +(lhs: Self, rhs: Self) -> Self {
        let (result, _) = lhs.overflowAdd(rhs)
        return result
    }

    static func -(lhs: Self, rhs: Self) -> Self {
        let (result, _) = lhs.overflowSub(rhs)
        return result
    }
}
