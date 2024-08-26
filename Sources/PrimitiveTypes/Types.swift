import Foundation

public protocol BigUInt: CustomStringConvertible, Equatable {
    /// `BigUInt` bytes
    var BYTES: [UInt64] { get }
    /// Max value
    static var MAX: Self { get }
    /// Zero value
    static var ZERO: Self { get }
    /// Number bytes of `BigUInt`
    static var numberBytes: UInt8 { get }
    /// Number base - count of `UInt64` (base) values. It's always: `numberBytes/8`
    static var numberBase: UInt8 { get }

    /// Is value zero
    var isZero: Bool { get }

    /// Init from low `UInt64`
    init(from value: UInt64)

    /// Init from array of `[UInt64]`.
    /// Ir suppose to be little endian array of values.
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
    init(from value: UInt64) {
        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        data[0] = value
        self = Self(from: data)
    }

    static var MAX: Self {
        Self(from: [UInt64](repeating: UInt64.max, count: Int(numberBytes / 8)))
    }

    static var ZERO: Self {
        Self(from: [UInt64](repeating: 0, count: Int(numberBytes / 8)))
    }

    static var numberBase: UInt8 {
        self.numberBytes / 8
    }

    var isZero: Bool {
        for i in 0 ..< Int(Self.numberBase) {
            if self.BYTES[i] != 0 {
                return false
            }
        }
        return true
    }

    static func fromLittleEndian(from val: [UInt8]) -> Self {
        precondition(val.count <= numberBytes, "BigUInt must be initialized with at least \(numberBytes) bytes.")

        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        for (index, byte) in val.enumerated() {
            let blockIndex = index / 8
            let bytePosition = index % 8
            data[blockIndex] |= UInt64(byte) << (bytePosition * 8)
        }

        return Self(from: data)
    }

    static func fromBigEndian(from val: [UInt8]) -> Self {
        precondition(val.count <= numberBytes, "BigUInt must be initialized with at most \(numberBytes) bytes.")

        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        for (index, byte) in val.reversed().enumerated() {
            let blockIndex = index / 8
            let bytePosition = index % 8
            data[blockIndex] |= UInt64(byte) << (bytePosition * 8)
        }

        return Self(from: data)
    }

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

    static func fromString(hex value: String) -> Self {
        precondition(value.count <= numberBytes * 2 && value.count % 2 == 0, "Invalid hex string for \(numberBytes) bytes.")

        var byteArray: [UInt8] = []
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            let byteString = String(value[index ..< nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                byteArray.append(byte)
            } else {
                assertionFailure("Invalid hex string byte for BigUInt.")
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
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.BYTES == rhs.BYTES
    }
}
