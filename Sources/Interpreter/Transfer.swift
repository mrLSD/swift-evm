import PrimitiveTypes

/// Transfer from source to target, with given value.
public struct Transfer {
    /// Source address.
    public var source: H160
    /// Target address.
    public var target: H160
    /// Transfer value.
    public var value: U256

    /// Initializes a new `Transfer` instance with the specified source, target, and value.
    public init(source: H160, target: H160, value: U256) {
        self.source = source
        self.target = target
        self.value = value
    }
}
