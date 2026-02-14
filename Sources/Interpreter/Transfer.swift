import PrimitiveTypes

/// Transfer from source to target, with given value.
public struct Transfer: Equatable, Sendable {
    /// Source address.
    public let source: H160
    /// Target address.
    public let target: H160
    /// Transfer value.
    public let value: U256

    /// Initializes a new `Transfer` instance with the specified source, target, and value.
    public init(source: H160, target: H160, value: U256) {
        self.source = source
        self.target = target
        self.value = value
    }
}
