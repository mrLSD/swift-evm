/// Machine Memory with  specific limit.
public struct Memory {
    /// Memory data
    private var data: [UInt8] = []
    /// Get Memory data
    public var getData: [UInt8] { self.data }

    /// Memory limit
    private(set) var limit: Int = 0

    /// Get Memory length
    public var length: Int { self.data.count }

    /// Memory effective length, that changed after resize operations.
    private(set) var effectiveLength: Int = 0

    /// Creates a new memory instance that can be shared between calls.
    /// With memory `limit` as upper bound for allocation size.
    init(limit: Int) {
        self.limit = limit
    }

    /// Creates a new memory instance that can be shared between calls.
    init() {
        self.limit = Int.max
    }

    /// Get memory data from range.
    ///
    /// ## Panics
    /// Panics if `range` is out of Memory data range
    /// If `range` value out of Memory diapason - just returns empty result
    func get(range: Range<Int>) -> [UInt8] {
        // Check Memory range
        precondition(range.lowerBound >= 0 && range.upperBound <= self.length, "Get Memory out of range: \(range)\n for 0..<(self.data.count)")

        return Array(self.data[range])
    }

    mutating func set(range: Range<Int>, with newData: [UInt8]) {
        // Check Memory range
        precondition(range.lowerBound >= 0 && range.upperBound <= self.data.count, "Set Memory out of range: \(range)\n for 0..<(self.data.count)")
        // Check new data length is also in new range
        precondition(range.count == newData.count, "Set Memory data length \(newData.count) out of set range \(range.count)")

        self.data.replaceSubrange(range, with: newData)
    }

    /// Resize memory  extending to specific size with zero data
    mutating func resize(size: Int) {
        let addSize = size - self.length
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
