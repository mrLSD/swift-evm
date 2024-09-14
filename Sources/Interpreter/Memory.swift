/// Machine Memory with  specific limit.
public struct Memory {
    private var data: [UInt8] = []
    private var limit: Int = 0

    /// Init Memory with empty data and Memory limit
    init(limit: Int) {
        self.limit = limit
    }

    /// Get Memory length
    func length() -> Int {
        self.data.count
    }

    /// Get memory data from range.
    ///
    /// ## Panics
    /// Panics if `range` is out of Memory data range
    /// If `range` value out of Memory diapason - just returns empty result
    func get(range: Range<Int>) -> [UInt8] {
        // Check Memory range
        precondition(range.lowerBound >= 0 && range.upperBound <= self.data.count, "Get Memory out of range: \(range)\n for 0..<(self.data.count)")

        return Array(self.data[range])
    }

    mutating func set(range: Range<Int>, with newData: [UInt8]) {
        // Check Memory range
        precondition(range.lowerBound >= 0 && range.upperBound <= self.data.count, "Set Memory out of range: \(range)\n for 0..<(self.data.count)")
        // Check new data lenth is also in new range
        precondition(range.count == newData.count, "Set Memory data length \(newData.count) out of set range \(range.count)")

        self.data.replaceSubrange(range, with: newData)
    }

    /// Resize memory  extending to specific size with zero data
    mutating func resize(size: Int) {
        let addSize = size - self.data.count
        if addSize <= 0 {
            return
        }
        self.data.append(contentsOf: [UInt8](repeating: 0, count: addSize))
    }

    /**
     Converts a unsigned integer to the next closest multiple of 32.

     - Parameters:
       - value: The value whose ceil32 is to be calculated.

     - Returns:
       The same value if it's a perfect multiple of 32 else it returns the smallest multiple of 32 that is greater than `value`.
     */
    public static func ceil32(_ value: UInt) -> UInt {
        let ceiling: UInt = 32
        let remainder = value % ceiling

        if remainder == 0 {
            return value
        } else {
            return value + ceiling - remainder
        }
    }
}
