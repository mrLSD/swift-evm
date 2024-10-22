public struct U128: BigUInt {
    private let bytes: [UInt64]

    public static let numberBytes: UInt8 = 16
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero

    public var BYTES: [UInt64] { bytes }

    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "U128 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
    }
}

extension U128 {
    public func divRem(divisor: U128) -> (quotient: U128, remainder: U128) {
        precondition(!divisor.isZero, "Division by zero")

        // If self < divisor, quotient is 0 and remainder is self
        if self < divisor {
            return (U128.ZERO, self)
        }

        // If divisor is 1, quotient is self and remainder is 0
        if divisor == U128(from: 1) {
            return (self, U128.ZERO)
        }

        // Normalize the divisor and dividend
        let (normalizedDivisor, normalizedDividend, shift) = normalize(divisor: divisor, dividend: self)

        let v0 = normalizedDivisor.BYTES[0]
        let v1 = normalizedDivisor.BYTES[1]

        let u0 = normalizedDividend.BYTES[0]
        let u1 = normalizedDividend.BYTES[1]

        // Estimate the quotient
        var qHat = u1 / v1
        var rHat = u1 % v1

        // Adjust q_hat if necessary
        while true {
            let (prodLow, prodOverflow) = v0.multipliedReportingOverflow(by: qHat)
            let product = U128(from: [prodLow, 0])
            let combinedU128 = U128(from: [u0, rHat])

            if prodOverflow || combinedU128 < product {
                qHat -= 1
                rHat += v1
                if rHat >= v1 {
                    continue
                }
            }
            break
        }

        // Multiply and subtract
        let productLow = v0 &* qHat // ignore overflow
        let (diffLow, borrow1) = u0.subtractingReportingOverflow(productLow)
        let (diffHigh, borrow2) = rHat.subtractingReportingOverflow(borrow1 ? 1 : 0)

        let rHigh = diffHigh
        var rLow = diffLow

        // If borrow occurred, adjust q_hat and the remainder
        if borrow2 {
            qHat -= 1
            rLow = diffLow &- v0 // ignore overflow
        }

        // Assemble the quotient
        let quotient = U128(from: [qHat, 0])

        // Denormalize the remainder
        let remainder = denormalize(remainder: U128(from: [rLow, rHigh]), shift: shift)

        return (quotient, remainder)
    }

    /// Normalizes the divisor and dividend
    func normalize(divisor: U128, dividend: U128) -> (normalizedDivisor: Self, normalizedDividend: Self, shift: Int) {
        let highWord = divisor.bytes[1]
        let lowWord = divisor.bytes[0]

        let shift: Int = if highWord != 0 {
            highWord.leadingZeroBitCount
        } else {
            64 + lowWord.leadingZeroBitCount
        }

        let normalizedV1: UInt64
        let normalizedV0: UInt64
        if shift >= 64 {
            let additionalShift = shift - 64
            normalizedV1 = lowWord << additionalShift
            normalizedV0 = 0
        } else {
            normalizedV1 = (highWord << shift) | (lowWord >> (64 - shift))
            normalizedV0 = lowWord << shift
        }

        let normalizedDivisor = U128(from: [normalizedV0, normalizedV1])

        let highWordD = dividend.bytes[1]
        let lowWordD = dividend.bytes[0]
        let normalizedU1: UInt64
        let normalizedU0: UInt64
        if shift >= 64 {
            let additionalShift = shift - 64
            normalizedU1 = lowWordD << additionalShift
            normalizedU0 = 0
        } else {
            normalizedU1 = (highWordD << shift) | (lowWordD >> (64 - shift))
            normalizedU0 = lowWordD << shift
        }

        let normalizedDividend = U128(from: [normalizedU0, normalizedU1])

        return (normalizedDivisor, normalizedDividend, shift)
    }

    /// Denormalizes the remainder
    func denormalize(remainder: Self, shift: Int) -> Self {
        let highWord = remainder.bytes[1]
        let lowWord = remainder.bytes[0]

        let denormalizedV1: UInt64
        let denormalizedV0: UInt64
        if shift >= 64 {
            let additionalShift = shift - 64
            denormalizedV1 = 0
            denormalizedV0 = highWord >> additionalShift
        } else {
            denormalizedV1 = highWord >> shift
            denormalizedV0 = (lowWord >> shift) | (highWord << (64 - shift))
        }

        return U128(from: [denormalizedV0, denormalizedV1])
    }
}
