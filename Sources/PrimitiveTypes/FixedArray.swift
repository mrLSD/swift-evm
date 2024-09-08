import Foundation

/// Fixed array represent numbers based on fixed  bytes (`UInt8`) array
public protocol FixedArray: CustomStringConvertible, Equatable {
    /// Fixed array bytes
    var BYTES: [UInt8] { get }
    /// Max value
    static var MAX: Self { get }
    /// Zero value
    static var ZERO: Self { get }
    /// Number bytes of `FixedArray`
    static var numberBytes: UInt8 { get }

    /// Is value zero
    var isZero: Bool { get }

    /// Init from bytes array.
    init(from value: [UInt8])

    /// Create `FixedArray` from hex `String`
    static func fromString(hex value: String) -> Self
}

public extension FixedArray {
    /// Calculate Max value
    static var getMax: Self {
        Self(from: [UInt8](repeating: UInt8.max, count: Int(self.numberBytes)))
    }

    /// Calculate Zero valued
    static var getZero: Self {
        Self(from: [UInt8](repeating: 0, count: Int(numberBytes)))
    }

    /// Calculate is value zero
    var isZero: Bool {
        for i in 0 ..< Int(Self.numberBytes) {
            if self.BYTES[i] != 0 {
                return false
            }
        }
        return true
    }

    static func fromString(hex value: String) -> Self {
        precondition(value.count <= numberBytes * 2, "Invalid hex string for \(numberBytes) bytes.")
        precondition(value.count % 2 == 0, "Invalid hex string for `mod 2`")

        var byteArray: [UInt8] = []
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            let byteString = String(value[index ..< nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                byteArray.append(byte)
            } else {
                assertionFailure("Invalid hex string byte character: \(byteString)")
            }
            index = nextIndex
        }

        return Self(from: byteArray)
    }
}

/// Implementation of `CustomStringConvertible`
public extension FixedArray {
    var description: String {
        self.BYTES.map { String(format: "%02lx", $0).uppercased() }.joined()
    }
}

/// Implementation of `Equatable`
public extension FixedArray {
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.BYTES == rhs.BYTES
    }
}
