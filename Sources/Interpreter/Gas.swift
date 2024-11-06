import PrimitiveTypes

/// Represents the state of gas during execution.
public struct Gas {
    /// The initial gas limit. This is constant throughout execution.
    let limit: UInt64
    /// The remaining gas.
    private(set) var remaining: UInt64
    /// Refunded gas. This is used only at the end of execution.
    private(set) var refunded: Int64
    /// Returns the total amount of gas spent.
    @inline(__always)
    var spent: UInt64 { self.limit - self.remaining }

    /// Creates a new `Gas` struct with the given gas limit.
    init(limit: UInt64) {
        self.limit = limit
        self.remaining = limit
        self.refunded = 0
    }

    /// Creates a new `Gas` struct with the given gas limit, but without any gas remaining.
    init(withoutRemain limit: UInt64) {
        self.limit = limit
        self.remaining = 0
        self.refunded = 0
    }

    /// Records a refund gas value.
    ///
    /// `refund` can be negative but `self.refunded` should always be positive
    /// at the end of transact.
    @inline(__always)
    mutating func recordRefund(refund: Int64) {
        self.refunded += refund
    }

    /// Sets the final refund based on the provided `isLondon` flag - London hard fork flag.
    ///
    /// This method adjusts the `refunded` property by taking the minimum of the current refunded amount
    /// and the spent amount divided by a quotient that depends on whether the London rules apply.
    ///
    /// - Parameter isLondon: A Boolean indicating whether London hard fork.
    mutating func setFinalRefund(isLondon: Bool) {
        let maxRefundQuotient: UInt64 = isLondon ? 5 : 2
        // Check UInt64 bounds to avoid overflow
        self.refunded = self.refunded < 0 ? 0 : Int64(min(UInt64(self.refunded), self.spent / maxRefundQuotient))
    }

    /// Records the gas cost by subtracting the given cost from the remaining gas.
    /// Returns `Overflow` status for the gas limit is exceeded.
    ///
    /// - Parameter cost: The cost to subtract.
    /// - Returns: `true` if the subtraction was successful without underflow, `false` otherwise.
    @inline(__always)
    mutating func recordCost(cost: UInt64) -> Bool {
        let (newRemaining, overflow) = self.remaining.subtractingReportingOverflow(cost)
        let success = !overflow
        if success {
            self.remaining = newRemaining
        }
        return success
    }
}

/// Gas constants for record gas cost calculation
enum GasConstant {
    static let BASE: UInt64 = 2
    static let VERYLOW: UInt64 = 3
    static let LOW: UInt64 = 5
    static let MID: UInt64 = 8
    static let EXP: UInt64 = 10

    // TODO: Add hard fork config
    static func expCost(power val: U256) -> UInt64 {
        if val.isZero {
            return self.EXP
        } else {
            // EIP-160: EXP cost increase
            // TODO: hard fork config
            let gasByte = U256(from: 50)
            // NOTE: overflow just impossible as max value: `gasByte * (256/8 + 1)`
            let logMul = gasByte * U256(from: Self.log2floor(val) / 8 + 1)
            let gas = U256(from: Self.EXP) + logMul
            return gas.BYTES[0]
        }
    }

    static func log2floor(_ val: U256) -> UInt64 {
        var l: UInt64 = 256
        for i in (0 ..< 4).reversed() {
            if val.BYTES[i] == 0 {
                l -= 64
            } else {
                l -= UInt64(val.BYTES[i].leadingZeroBitCount)
                return l &- 1
            }
        }
        return l
    }
}
