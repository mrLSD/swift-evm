/// EVM core execution layer
public struct Machine {
    /// Program data
    private let data: [UInt8]
    /// Program code.
    private let code: [UInt8]
    /// Program counter.
    private let pc: UInt
    /// Return value.
    private let returnRange: Range<UInt64>

    /// Code validity maps.
    // private let   valids: Valids,
    /// Memory.
    // memory: Memory,
    /// Stack.
    // stack: Stack,
}
