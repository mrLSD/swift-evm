/// Utils for `divModWord` function. It was excluded for tests code coverage reason.
/// It's impossible to coverage `@available` directive, that cover `UInt128` new types.
/// Struct includes functions for `divModWord` based on `UInt64` and `Uint128`.
enum DivModUtils {
    /// divMod for `UInt64` types
    static func divModWord64(hi: UInt64, lo: UInt64, y: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        var quotient: UInt64 = 0
        var remainder: UInt64 = hi

        // Iterate over each bit of the lower 64 bits, from highest to lowest
        for i in (0 ..< 64).reversed() {
            // Shift remainder left by 1 and add the current bit of lo
            remainder = (remainder << 1) | ((lo >> i) & 1)

            // If the remainder is greater than or equal to y, subtract y and set the corresponding bit in quotient
            if remainder >= y {
                remainder -= y
                quotient |= (1 << i)
            }
        }
        return (quotient, remainder)
    }

    /// divMod for `UInt128` types
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    static func divModWordU128(hi: UInt64, lo: UInt64, y: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        // Construct the 128-bit number from hi and lo
        let x = (UInt128(hi) << 64) + UInt128(lo)
        let y128 = UInt128(y)

        // Perform division and modulus using UInt128
        let quotient = UInt64(x / y128)
        let remainder = UInt64(x % y128)
        return (quotient, remainder)
    }

    /// Computes the quotient and remainder of dividing a 128-bit unsigned integer by `y`.
    ///
    /// The dividend is represented as two 64-bit words: `hi` (most significant) and `lo` (least significant),
    /// i.e., `x = (hi << 64) + lo`. The result quotient fits into `UInt64`.
    ///
    /// - Parameters:
    ///   - hi: High 64 bits of the dividend.
    ///   - lo: Low 64 bits of the dividend.
    ///   - y: Divisor.
    /// - Returns: A tuple containing:
    ///   - quotient: `floor(x / y)` as `UInt64`.
    ///   - remainder: `x % y` as `UInt64`.
    /// - Precondition: `y` must not be zero.
    /// - Note: Uses `UInt128` fast path on supported OS (i.e. Swift 6) versions; otherwise falls back to a bitwise long\-division implementation.
    static func divModWord(hi: UInt64, lo: UInt64, y: UInt64) -> (quotient: UInt64, remainder: UInt64) {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            return self.divModWordU128(hi: hi, lo: lo, y: y)
        } else {
            return self.divModWord64(hi: hi, lo: lo, y: y)
        }
    }
}
