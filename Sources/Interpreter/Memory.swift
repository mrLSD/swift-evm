import Foundation

struct Memory {
    private var data: [UInt8] = []
    private var limit: Int = 0

    init(limit: Int) {
        self.limit = limit
    }

    func length() -> Int {
        self.data.count
    }
}
