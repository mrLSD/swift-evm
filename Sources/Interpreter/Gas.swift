import PrimitiveTypes

/// Represents the state of gas during execution.
public struct Gas {
    /// The initial gas limit. This is constant throughout execution.
    let limit: UInt64
    var memoryGas: MemoryGas = .init()
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

/// Memory gas data
struct MemoryGas {
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
}

/// Gas cost calculations
enum GasCost {
    /// Calculates the memory gas cost for a given number of words.
    /// Formula: `3 * N + (N * N) / 512`
    ///
    /// - Parameter numWords: The number of 32-byte words (N).
    /// - Returns: A tuple containing:
    ///   - `cost`: The computed gas cost.
    ///   - `overflow`: True if the calculation exceeds UInt64 capacity.
    static func memoryGas(numWords: Int) -> (cost: UInt64, overflow: Bool) {
        let wordCount = UInt64(numWords)
        let quadraticDivisor: UInt64 = 512

        // 1. Calculate the Square (N * N)
        // This is the critical check. If N * N fits into UInt64, then N is guaranteed to be < 2^32.
        // If this overflows, the calculation is impossible within 64-bit bounds.
        let (square, squareOverflow) = wordCount.multipliedReportingOverflow(by: wordCount)
        if squareOverflow {
            return (0, true)
        }

        // 2. Calculate Linear Cost (3 * N)
        // We do not need an overflow check here.
        // Reasoning: Since step 1 passed, we know N < 2^32.
        // Therefore, 3 * N is roughly 3 * 2^32, which is drastically smaller than UInt64.max (2^64).
        let linearCost = GasConstant.MEMORY * wordCount

        // 3. Calculate Quadratic Cost Part (N^2 / 512)
        let quadraticCost = square / quadraticDivisor

        // 4. Final Summation
        // We do not need an overflow check here.
        // Reasoning: The maximum possible value of `quadraticCost` is (UInt64.max / 512).
        // The `linearCost` (approx 1.2 * 10^10) is negligible compared to the remaining space in UInt64.
        // The sum is mathematically guaranteed to fit.
        let totalGas = linearCost + quadraticCost

        return (totalGas, false)
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
    /// - Note: Overflow is impossible as the maximum value is `gasByte * (256/8 + 1)`
    static func expCost(hardFork: HardFork, power: U256) -> UInt64 {
        if power.isZero {
            return GasConstant.EXP
        } else {
            // EIP-160: EXP cost increase
            let gasByte = U256(from: hardFork.isSpuriousDragon() ? 50 : 10)
            // NOTE: overflow just impossible as max value: `gasByte * (256/8 + 1)`
            let logMul = gasByte * U256(from: Self.log2floor(power) / 8 + 1)
            let gas = U256(from: GasConstant.EXP) + logMul
            return gas.BYTES[0]
        }
    }

    /// Calculates the floor of the base-2 logarithm of a 256-bit unsigned integer (For EXP opcode).
    ///
    /// This function computes log₂(val) rounded down to the nearest integer by finding
    /// the position of the most significant bit. It iterates through the bytes of the
    /// U256 value from most significant to least significant, counting leading zero bits
    /// to determine the highest set bit position.
    ///
    /// - Parameter val: The 256-bit unsigned integer to calculate the log₂ floor for
    /// - Returns: The floor of log₂(val) as a UInt64. Returns 256 if val is 0.
    ///
    /// - Note: The result is the zero-based index of the most significant set bit,
    ///   effectively computing floor(log₂(val)) for positive values.
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
