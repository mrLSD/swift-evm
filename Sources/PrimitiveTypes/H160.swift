import Foundation

public struct H160: FixedArray {
    private var bytes: [UInt8]

    public static let numberBytes: UInt8 = 20
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero

    public var BYTES: [UInt8] { bytes }

    public init(from bytes: [UInt8]) {
        precondition(bytes.count == Self.numberBytes, "H160 must be initialized with \(Self.numberBytes) bytes array.")
        self.bytes = bytes
    }
}
