import Foundation

/// `BigUInt` Protocol - represent Bit Unsigner Integers
public protocol BigUInt: CustomStringConvertible, Equatable, Sendable {
    /// `BigUInt` bytes
    var BYTES: [UInt64] { get }
    /// Calculate`BigUInt` Max value
    static var MAX: Self { get }
    /// Calculate `BigUInt` Zero value
    static var ZERO: Self { get }
    /// Number bytes of `BigUInt`
    static var numberBytes: UInt8 { get }
    /// Number base - count of `UInt64` (base) values. It's always: `numberBytes/8`
    static var numberBase: UInt8 { get }

    /// Is `BigUInt` value zero
    var isZero: Bool { get }

    /// Init `BigUInt` from low `UInt64`
    init(from value: UInt64)

    /// Init `BigUInt` from array of `[UInt64]`.
    /// It suppose to be little endian array of values.
    init(from value: [UInt64])

    /// Create `BitUInt` from `little-endian` array
    static func fromLittleEndian(from val: [UInt8]) -> Self

    /// Create `BitUInt` from `big-endian` array
    static func fromBigEndian(from val: [UInt8]) -> Self

    /// Create `BigUInt` from hex `String`
    static func fromString(hex value: String) -> Self

    /// Convert `BigUInt` to `little-endian` array
    var toLittleEndian: [UInt8] { get }

    /// Convert `BigUInt` to `big-endian` array
    var toBigEndian: [UInt8] { get }
}

public extension BigUInt {
    /// Init `BigUInt` form `UInt64`
    init(from value: UInt64) {
        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        data[0] = value
        self = Self(from: data)
    }

    /// Calculate `BigUInt` Max value
    static var getMax: Self {
        Self(from: [UInt64](repeating: UInt64.max, count: Int(numberBase)))
    }

    /// Calculate `BigUInt` Zero valued
    static var getZero: Self {
        Self(from: [UInt64](repeating: 0, count: Int(numberBase)))
    }

    /// Number base - count of `UInt64` (base) values. It's always: `numberBytes/8`
    static var numberBase: UInt8 {
        self.numberBytes / 8
    }

    /// Get Uint value from `BigUInt`.
    ///
    /// - Returns:
    ///   - `UInt` must be less than or equal to `UInt64(UInt.max)`. On 32-bit systems. For 64-bit systems always successful.
    ///     `nil` corresponds to 32-bit systems, when `UInt` is greater than `UInt32.max`.
    var getUInt: UInt? {
        UInt(exactly: self.BYTES[0])
    }

    /// Calculate is `BigUInt` value zero
    var isZero: Bool {
        for i in 0 ..< Int(Self.numberBase) {
            if self.BYTES[i] != 0 {
                return false
            }
        }
        return true
    }

    /// Create `BitUInt` from `little-endian` array
    ///
    /// - Precondition:
    ///   - `from` value must be less than or equal to `numberBytes` of `BigUInt`.
    static func fromLittleEndian(from val: [UInt8]) -> Self {
        precondition(val.count <= numberBytes, "BigUInt must be initialized with not more than \(numberBytes) bytes.")

        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        for (index, byte) in val.enumerated() {
            let blockIndex = index / 8
            let bytePosition = index % 8
            data[blockIndex] |= UInt64(byte) << (bytePosition * 8)
        }

        return Self(from: data)
    }

    /// Create `BitUInt` from `big-endian` array
    ///
    /// - Precondition:
    ///   - `from` value must be less than or equal to `numberBytes` of `BigUInt`.
    static func fromBigEndian(from val: [UInt8]) -> Self {
        precondition(val.count <= numberBytes, "BigUInt must be initialized with not more than \(numberBytes) bytes.")

        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        for (index, byte) in val.reversed().enumerated() {
            let blockIndex = index / 8
            let bytePosition = index % 8
            data[blockIndex] |= UInt64(byte) << (bytePosition * 8)
        }

        return Self(from: data)
    }

    /// Convert `BigUInt` to `little-endian` array
    var toLittleEndian: [UInt8] {
        var byteArray: [UInt8] = []

        for block in self.BYTES {
            for i in 0 ..< 8 {
                let byte = UInt8((block >> (i * 8)) & 0xFF)
                byteArray.append(byte)
            }
        }

        return byteArray
    }

    /// Convert `BigUInt` to `big-endian` array
    var toBigEndian: [UInt8] {
        var byteArray: [UInt8] = []

        for block in self.BYTES.reversed() {
            for i in (0 ..< 8).reversed() {
                let byte = UInt8((block >> (i * 8)) & 0xFF)
                byteArray.append(byte)
            }
        }

        return byteArray
    }

    /// Create `BigUInt` from hex `String`
    ///
    /// - Precondition:
    ///   - `value.count` value must be less than or equal to ` numberBytes * 2` of `BigUInt`.
    ///   - `value.count` value must be ` mod 2`.
    ///   - `hex` value of the `String` must be  equal `1 byte (8 bit)`.
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
                fatalError("Invalid hex string byte character: \(byteString)")
            }
            index = nextIndex
        }

        return Self.fromLittleEndian(from: byteArray)
    }
}

/// Implementation of `CustomStringConvertible`
public extension BigUInt {
    var description: String {
        self.BYTES.map { String(format: "%016lx", $0).uppercased() }.joined()
    }
}

/// Implementation of `Equatable`
public extension BigUInt {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.BYTES == rhs.BYTES
    }

    /// Operator `!=`: Check if two `BigUInt` values are not equal
    static func != (lhs: Self, rhs: Self) -> Bool {
        !(lhs == rhs)
    }

    /// Operator `<`: Compare two `BigUInt` values
    ///
    /// For arbitrary precision numbers, as for any number, the digit with the greatest weight
    /// (the most significant digit) is the most important when comparing.
    static func < (lhs: Self, rhs: Self) -> Bool {
        // Reversed iteration
        for i in stride(from: Int(self.numberBase) - 1, through: 0, by: -1) {
            if lhs.BYTES[i] < rhs.BYTES[i] {
                return true
            } else if lhs.BYTES[i] > rhs.BYTES[i] {
                return false
            }
        }
        // If all blocks are equal
        return false
    }

    /// Operator `>`: Compare two `BigUInt` values
    static func > (lhs: Self, rhs: Self) -> Bool {
        rhs < lhs
    }

    /// Operator `<=`: Compare two `BigUInt` values for less than or equal
    static func <= (lhs: Self, rhs: Self) -> Bool {
        !(lhs > rhs)
    }

    /// Operator `>=`: Compare two `BigUInt` values for less than or equal
    static func >= (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs)
    }
}
