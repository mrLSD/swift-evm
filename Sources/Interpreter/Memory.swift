/// Machine Memory with  specific limit.
struct Memory {
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
    /// If `range` value out of Memory diapason - just returns empty result
    func get(range: Range<Int>) -> [UInt8] {
        // Check range
        guard range.lowerBound >= 0, range.upperBound <= self.data.count else { return [] }

        return Array(self.data[range])
    }

    /// Resize extending memory to specific size with zero data
    mutating func resize(size: Int) {
        let addSize = size - self.data.count
        if addSize <= 0 {
            return
        }
        self.data.append(contentsOf: [UInt8](repeating: 0, count: addSize))
    }
}
