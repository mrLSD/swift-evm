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
    static let HIGH: UInt64 = 10
    static let JUMPDEST: UInt64 = 1
    static let EXP: UInt64 = 10
    static let MEMORY: UInt64 = 3
    static let COPY: UInt64 = 3
}

enum GasCost {
    /// Resizes the memory to a new end position and calculates the additional gas cost required.
    ///
    /// It then subtracts the current gas cost from the new gas cost to determine the additional cost.
    /// If any of the calculations overflow, the function returns a failure with an `.OutOfGas` error.
    ///
    /// - Parameters:
    ///   - end: The new end address of the memory.
    ///   - length: The current length of the memory.
    /// - Returns: A `Result` containing:
    ///   - `UInt64`: The additional gas cost if the operation is successful.
    ///   - `Machine.ExitError`: `.OutOfGas` error if an overflow occurs during the calculation.
    static func resize(end: UInt, length: UInt) -> Result<UInt64, Machine.ExitError> {
        let newSize = Memory.ceil32(Int(clamping: end))

        let (newGasCost, overflow1) = Self.memoryGas(numWords: UInt64(Memory.numWords(UInt(newSize))))
        guard !overflow1 else {
            return .failure(.OutOfGas)
        }

        let (currentGasCost, overflow2) = GasCost.memoryGas(numWords: UInt64(Memory.numWords(length)))
        guard !overflow2 else {
            return .failure(.OutOfGas)
        }

        let cost = newGasCost - currentGasCost
        return .success(cost)
    }

    /// Calculates the memory gas cost for a given number of words.
    ///
    /// - Parameters:
    ///   - numWords: The number of words for which the gas cost is calculated.
    /// - Returns: A tuple containing:
    ///   - `UInt64`: The computed gas cost (0 if an overflow occurs).
    ///   - `Bool`: A flag indicating the success of the calculation (true if no overflow occurred, false otherwise).
    static func memoryGas(numWords: UInt64) -> (UInt64, Bool) {
        let (mul1, overflow1) = GasConstant.MEMORY.multipliedReportingOverflow(by: numWords)
        if overflow1 {
            return (0, false)
        }
        let (mul2, overflow2) = numWords.multipliedReportingOverflow(by: numWords)
        if overflow2 {
            return (0, false)
        }
        let (result, overflow3) = mul1.addingReportingOverflow(mul2)
        return (result, !overflow3)
    }

    /// Calculates the gas cost for a "very low" and copy operation on a memory segment of a given size.
    ///
    /// The function first computes the cost per word by multiplying the number of memory words (derived from the given size)
    /// by a multiplier that is clamped from `COPY`. If this multiplication overflows, the function returns `nil`.
    /// It then adds the constant base cost `VERYLOW` to the computed cost per copy.
    /// If the addition overflows, the function also returns `nil`.
    ///
    /// - Parameter size: The size of the memory segment to be copied.
    /// - Returns: The computed gas cost as a `UInt64`, or `nil` if an arithmetic overflow occurs.
    static func veryLowCopy(size: UInt) -> UInt64? {
        guard let costPerCopy = costPerWord(size: size, multiple: UInt(clamping: GasConstant.COPY)) else {
            return nil
        }
        let (res, overflow) = GasConstant.VERYLOW.addingReportingOverflow(UInt64(costPerCopy))
        return overflow ? nil : res
    }

    /// Calculates the cost per word by multiplying the number of memory words for a given size by a specified multiplier.
    ///
    /// - Parameters:
    ///   - size: The memory size for which the number of words is determined.
    ///   - multiple: The multiplier used to calculate the cost per word.
    /// - Returns: The calculated cost per word as a `UInt`, or `nil` if an arithmetic overflow occurs.
    static func costPerWord(size: UInt, multiple: UInt) -> UInt? {
        let (numWords, overflow) = Memory.numWords(size).multipliedReportingOverflow(by: multiple)
        return overflow ? nil : numWords
    }

    // TODO: Add hard fork config
    static func expCost(power val: U256) -> UInt64 {
        if val.isZero {
            return GasConstant.EXP
        } else {
            // EIP-160: EXP cost increase
            // TODO: hard fork config
            let gasByte = U256(from: 50)
            // NOTE: overflow just impossible as max value: `gasByte * (256/8 + 1)`
            let logMul = gasByte * U256(from: Self.log2floor(val) / 8 + 1)
            let gas = U256(from: GasConstant.EXP) + logMul
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
