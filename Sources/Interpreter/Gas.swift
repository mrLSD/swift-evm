import PrimitiveTypes

/// Represents the state of gas during execution.
public struct Gas: Equatable, Sendable {
    /// The initial gas limit. This is constant throughout execution.
    let limit: UInt64
    var memoryGas: MemoryGas = .init()
    /// The remaining gas.
    private(set) var remaining: UInt64
    /// Refunded gas. This is used only at the end of execution.
    private(set) var refunded: Int64
    /// Returns the total amount of gas spent.
    @inline(__always)
    var spent: UInt64 {
        self.limit - self.remaining
    }

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

    /// Records a stipend gas value.
    @inline(__always)
    mutating func recordStipend(stipend: UInt64) {
        let (newRemaining, overflow) = self.remaining.addingReportingOverflow(stipend)
        if overflow || newRemaining > self.limit {
            // Clamp to the gas limit to preserve the invariant `remaining <= limit`
            self.remaining = self.limit
        } else {
            self.remaining = newRemaining
        }
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

/// Memory gas data
struct MemoryGas: Equatable {
    /// Number of words in memory. Used for memory resize gas calculation
    var numWords: Int = 0
    /// Memory gas cost
    var gasCost: UInt64 = 0

    /// Represents the result status of a memory gas resize operation.
    ///
    /// - Unchanged: Indicates that the memory size did not change, hence no additional gas cost was incurred.
    /// - Resized(UInt64): Indicates that the memory was resized, with the associated UInt64 representing the additional gas cost.
    enum MemoryGasStatus: Equatable {
        case Unchanged
        case Resized(UInt64)
    }

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
    mutating func resize(end: Int, length: Int) -> Result<MemoryGasStatus, Machine.ExitError> {
        let (newSize, overflow) = end.addingReportingOverflow(length)
        guard !overflow else {
            return .failure(.OutOfGas)
        }

        let numWords = Memory.numWords(newSize)
        guard numWords > self.numWords else {
            return .success(.Unchanged)
        }

        let (newGasCost, overflow1) = GasCost.memoryGas(numWords: numWords)
        if overflow1 {
            return .failure(.OutOfGas)
        }

        // Set numWords only after all checks passed
        self.numWords = numWords

        // As we checked `numWords`, subtraction can't overflow
        let cost = newGasCost - self.gasCost
        self.gasCost = newGasCost

        return .success(.Resized(cost))
    }
}

/// Gas constants for record gas cost calculation
enum GasConstant {
    /// Base gas cost for basic operations.
    static let BASE: UInt64 = 2
    /// Gas cost for very low-cost operations.
    static let VERYLOW: UInt64 = 3
    /// Gas cost for low-cost operations.
    static let LOW: UInt64 = 5
    /// Gas cost for medium-cost operations.
    static let MID: UInt64 = 8
    /// Gas cost for high-cost operations.
    static let HIGH: UInt64 = 10
    static let JUMPDEST: UInt64 = 1
    /// Base gas cost for EXP instruction.
    static let EXP: UInt64 = 10
    /// Gas cost per word for memory operations.
    static let MEMORY: UInt64 = 3
    /// Gas cost per word for copy operations.
    static let COPY: UInt64 = 3
    static let COLD_ACCOUNT_ACCESS_COST: UInt64 = 2600
    static let WARM_STORAGE_READ_COST: UInt64 = 100
    /// Base gas cost for KECCAK256 instruction.
    static let KECCAK256: UInt64 = 30
    /// Gas cost per word for KECCAK256 instruction.
    static let KECCAK256WORD: UInt64 = 6
    /// Base gas cost for LOG instructions.
    static let LOG: UInt64 = 375
    /// Gas cost per byte of log data.
    static let LOGDATA: UInt64 = 8
    /// Gas cost per log topic.
    static let LOGTOPIC: UInt64 = 375
}

/// Gas cost calculations
enum GasCost {
    /// Calculates the gas cost for a LOG instruction, excluding memory expansion.
    /// Formula: `375 + 8 * size + 375 * n`
    ///
    /// - Parameters:
    ///   - size: The nonnegative number of bytes in the log data.
    ///   - n: The number of topics, from 0 through 4.
    /// - Returns: The computed gas cost, or `nil` if it exceeds `UInt64` capacity.
    static func logCost(size: Int, n: Int) -> UInt64? {
        precondition(size >= 0 && (0 ... 4).contains(n), "LOG requires a nonnegative size and 0...4 topics.")
        let (dataCost, dataOverflow) = UInt64(size).multipliedReportingOverflow(by: GasConstant.LOGDATA)
        let (cost, costOverflow) = dataCost.addingReportingOverflow(GasConstant.LOG + GasConstant.LOGTOPIC * UInt64(n))

        return dataOverflow || costOverflow ? nil : cost
    }

    /// Calculates the total memory cost: `3 * N + floor(N * N / 512)`.
    ///
    /// This is the cumulative cost for `N` words, not the expansion cost.
    /// The caller subtracts the cost of the previously paid memory size.
    ///
    /// The square is evaluated at full width because it may exceed UInt64
    /// even when the quadratic term and the total cost still fit.
    /// For example, when `N == 2^32`, the square is `2^64`, but dividing
    /// it by 512 gives `2^55`.
    ///
    /// This function neither saturates the result nor checks the available
    /// gas budget. The caller must reject overflow and charge the expansion
    /// cost before allocating memory.
    ///
    /// - Parameter numWords: The nonnegative number of 32-byte words.
    /// - Returns: The exact cost and `false` if the total fits in UInt64;
    ///   otherwise, zero and `true`. Zero on overflow is not a valid gas cost.
    static func memoryGas(numWords: Int) -> (cost: UInt64, overflow: Bool) {
        let wordCount = UInt64(numWords)
        let quadraticDivisor: UInt64 = 512
        let quadraticShift = quadraticDivisor.trailingZeroBitCount

        // Preserve the entire square as two 64-bit words:
        // N^2 = high * 2^64 + low.
        let (high, low) = wordCount.multipliedFullWidth(by: wordCount)

        // N is not restricted to values whose square fits in UInt64,
        // so calculate the linear term with an explicit overflow check.
        let (linearCost, linearOverflow) = GasConstant.MEMORY.multipliedReportingOverflow(by: wordCount)

        // Since 512 == 2^9:
        // floor(N^2 / 512) = high * 2^55 + floor(low / 2^9).
        //
        // This quotient fits in UInt64 exactly when high < 512:
        // high >= 512 makes the first term at least 2^64.
        guard !linearOverflow, high < quadraticDivisor else {
            return (0, true)
        }

        // The validated high word contributes bits 55...63.
        // Shifting low right by 9 contributes bits 0...54 and discards
        // the remainder, implementing floor division.
        // These bit ranges do not overlap, so OR is equivalent to addition.
        let quadraticCost = (high << (UInt64.bitWidth - quadraticShift)) | (low >> quadraticShift)

        // Representable terms do not guarantee a representable sum.
        // For example, N == 97_184_015_232 passes the checks above,
        // but its total cost exceeds UInt64.max.
        let (totalGas, overflow) = linearCost.addingReportingOverflow(quadraticCost)
        return (overflow ? 0 : totalGas, overflow)
    }

    /// Calculates the gas cost for a "very low" and copy operation on a memory segment of a given size.
    ///
    /// The function first computes the cost per word by multiplying the number of memory words (derived from the given size)
    /// by a multiplier that is clamped from `COPY`.
    /// It then adds the constant base cost `VERYLOW` to the computed cost per copy.
    ///
    /// - Parameter size: The size of the memory segment to be copied.
    /// - Returns: The computed gas cost as a `UInt64`
    static func veryLowCopy(size: Int) -> UInt64 {
        // Overflow impossible in that case
        let costPerCopy = self.costPerWord(size: size, multiple: Int(clamping: GasConstant.COPY))!
        return GasConstant.VERYLOW + costPerCopy
    }

    /// Calculates the cost per word by multiplying the number of memory words for a given size by a specified multiplier.
    ///
    /// - Parameters:
    ///   - size: The memory size for which the number of words is determined.
    ///   - multiple: The multiplier used to calculate the cost per word.
    /// - Returns: The calculated cost per word as a `UInt`, or `nil` if an arithmetic overflow occurs.
    static func costPerWord(size: Int, multiple: Int) -> UInt64? {
        let (numWords, overflow) = Memory.numWords(size).multipliedReportingOverflow(by: multiple)
        return overflow ? nil : UInt64(numWords)
    }

    /// Calculates the gas cost for the EXP opcode based on the hard fork and exponent value.
    ///
    /// The gas cost varies depending on the hard fork version and the size of the exponent:
    /// - For zero exponent: returns base EXP gas constant
    /// - For non-zero exponent: applies EIP-160 cost increase based on exponent byte size
    ///
    /// - Parameters:
    ///   - hardFork: The Ethereum hard fork version that determines gas pricing rules
    ///   - power: The exponent value (U256) used in the exponential operation
    /// - Returns: The calculated gas cost as UInt64
    ///
    /// - Note: EIP-160 (Spurious Dragon hard fork) increased the per-byte cost from 10 to 50 gas
    /// - Note: Overflow is impossible as the maximum value is `EXP + gasByte * 32`
    static func expCost(hardFork: HardFork, power: U256) -> UInt64 {
        if power.isZero {
            return GasConstant.EXP
        }
        // EIP-160: EXP cost increase
        let gasByte: UInt64 = hardFork.isSpuriousDragon() ? 50 : 10
        // `log2floor(power) / 8 + 1` is the byte length of the exponent.
        return GasConstant.EXP + gasByte * (Self.log2floor(power) / 8 + 1)
    }

    /// Calculates the floor of the base-2 logarithm of a 256-bit unsigned integer (For EXP opcode).
    ///
    /// - Parameter val: The 256-bit unsigned integer to calculate the log₂ floor for
    /// - Returns: The zero-based index of the most significant set bit, or 0 for zero, which `expCost` prices separately.
    static func log2floor(_ val: U256) -> UInt64 {
        val.isZero ? 0 : UInt64(255 - val.leadingZeroBitCount)
    }

    /// Calculates the gas cost for account access based on whether the account is cold or warm.
    ///
    /// This function implements EIP-2929 gas cost calculation for account access operations.
    /// Cold accounts require higher gas costs on first access, while warm accounts (already accessed
    /// in the current transaction) have reduced costs for subsequent operations.
    ///
    /// - Parameter isCold: A boolean indicating whether the account is cold (not previously accessed)
    /// - Returns: The gas cost as a UInt64 value - either COLD_ACCOUNT_ACCESS_COST for cold accounts
    ///           or WARM_STORAGE_READ_COST for warm accounts
    static func warmOrColdCost(isCold: Bool) -> UInt64 {
        if isCold {
            GasConstant.COLD_ACCOUNT_ACCESS_COST
        } else {
            GasConstant.WARM_STORAGE_READ_COST
        }
    }

    /// `KECCAK256` opcode cost calculation.
    static func keccak256Cost(size: Int) -> UInt64 {
        // Overflow impossible in that case
        let costPerWord = self.costPerWord(size: size, multiple: Int(clamping: GasConstant.KECCAK256WORD))!

        return GasConstant.KECCAK256 + costPerWord
    }
}
