public struct Gas {
    /// The initial gas limit. This is constant throughout execution.
    let limit: UInt64
    /// The remaining gas.
    let remaining: UInt64
    /// Refunded gas. This is used only at the end of execution.
    let refunded: Int64

    init(limit: UInt64, remaining: UInt64, refunded: Int64) {
        self.limit = limit
        self.remaining = remaining
        self.refunded = refunded
    }
}
