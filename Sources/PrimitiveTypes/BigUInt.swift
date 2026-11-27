/// Fixed-width limb storage and the operations required by the EVM.
public protocol BigUInt: CustomStringConvertible, Equatable, Sendable, Hashable {
    /// `BigUInt` bytes
    var BYTES: [UInt64] { get }
    /// Calculate`BigUInt` Max value
    static var MAX: Self { get }
    /// Calculate `BigUInt` Zero value
    static var ZERO: Self { get }
    /// Number of bytes in `BigUInt`
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

    /// Division semantics belong to the concrete type, including through generic calls.
    static func / (lhs: Self, rhs: Self) -> Self
    static func % (lhs: Self, rhs: Self) -> Self
    static func /= (lhs: inout Self, rhs: Self)
    static func %= (lhs: inout Self, rhs: Self)

    /// Create `BigUInt` from `little-endian` array
    static func fromLittleEndian(from val: [UInt8]) -> Self

    /// Create `BigUInt` from `big-endian` array
    static func fromBigEndian(from val: [UInt8]) -> Self

    /// Parses ASCII hex digits after an optional `0x` or `0X` byte prefix.
    static func fromString(hex value: String) -> Result<Self, HexStringError>

    /// Encode to hex string with lowercase characters.
    func encodeHexLower() -> String

    /// Encode to hex string with uppercase characters.
    func encodeHexUpper() -> String

    /// Encode to hex string.
    /// - Parameter uppercase: Use uppercase hex characters.
    func hexString(uppercase: Bool) -> String

    /// Convert `BigUInt` to `little-endian` array
    var toLittleEndian: [UInt8] { get }

    /// Convert `BigUInt` to `big-endian` array
    var toBigEndian: [UInt8] { get }
}

extension BigUInt {
    /// Calculate `BigUInt` Max value
    static var getMax: Self {
        Self(from: [UInt64](repeating: UInt64.max, count: Int(numberBase)))
    }

    /// Calculate `BigUInt` Zero valued
    static var getZero: Self {
        Self(from: [UInt64](repeating: 0, count: Int(numberBase)))
    }
}

/// Implementation of `BigUInt` common functionality
public extension BigUInt {
    /// Init `BigUInt` from `UInt64`
    init(from value: UInt64) {
        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        data[0] = value
        self = Self(from: data)
    }

    /// Number base - count of `UInt64` (base) values. It's always: `numberBytes/8`
    static var numberBase: UInt8 {
        self.numberBytes / 8
    }

    /// Converts the stored magnitude to UInt, or nil if it exceeds the host width.
    var getUInt: UInt? {
        guard BYTES.dropFirst().allSatisfy({ $0 == 0 }) else { return nil }
        return UInt(exactly: BYTES[0])
    }

    /// Converts the stored magnitude to Int, or nil if it exceeds Int.max.
    var getInt: Int? {
        guard BYTES.dropFirst().allSatisfy({ $0 == 0 }) else { return nil }
        return Int(exactly: BYTES[0])
    }

    /// Converts the stored magnitude to Int, clamping oversized EVM offsets to Int.max.
    var saturatingInt: Int {
        return self.getInt ?? Int.max
    }

    /// Calculate is `BigUInt` value zero
    var isZero: Bool {
        return self.BYTES.allSatisfy { $0 == 0 }
    }

    /// Create `BigUInt` from `little-endian` array
    ///
    /// - Precondition:
    ///   - `from` value must be less than or equal to `numberBytes` of `BigUInt`.
    static func fromLittleEndian(from val: [UInt8]) -> Self {
        precondition(val.count <= self.numberBytes, "BigUInt must be initialized with not more than \(numberBytes) bytes.")

        var data = [UInt64](repeating: 0, count: Int(Self.numberBase))
        for (index, byte) in val.enumerated() {
            let blockIndex = index / 8
            let bytePosition = index % 8
            data[blockIndex] |= UInt64(byte) << (bytePosition * 8)
        }

        return Self(from: data)
    }

    /// Create `BigUInt` from `big-endian` array
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

    /// Parses ASCII hex digits after an optional `0x` or `0X` byte prefix.
    /// Checks the UTF-8 byte limit before reporting the first invalid character pair.
    static func fromString(hex value: String) -> Result<Self, HexStringError> {
        let bytes = value.utf8
        let hasPrefix = bytes.starts(with: "0x".utf8) || bytes.starts(with: "0X".utf8)
        let digits = bytes.dropFirst(hasPrefix ? 2 : 0)
        if digits.isEmpty {
            return .success(Self.ZERO)
        }

        let length = digits.count
        if length > Int(numberBytes) * 2 {
            return .failure(.InvalidStringLength)
        }

        var byteArray: [UInt8] = []
        byteArray.reserveCapacity((length + 1) / 2)
        var high: UInt8? = length.isMultiple(of: 2) ? nil : 0
        for byte in digits {
            guard let nibble = hexDecodeNibble(byte) else {
                return .failure(.InvalidHexCharacter(invalidHexPair(in: digits)))
            }

            if let first = high {
                byteArray.append((first << 4) | nibble)
                high = nil
            } else {
                high = nibble
            }
        }

        return .success(Self.fromBigEndian(from: byteArray))
    }
}

/// Implementation of `CustomStringConvertible` and Hex Encoding
public extension BigUInt {
    /// Canonical string representation (Lowercase hex, stripped leading zeros)
    var description: String {
        self.encodeHexLower()
    }

    /// Encode to hex string with lowercase characters.
    func encodeHexLower() -> String {
        return self.hexString(uppercase: false)
    }

    /// Encode to hex string with uppercase characters.
    func encodeHexUpper() -> String {
        return self.hexString(uppercase: true)
    }

    /// Encode to hex string.
    /// - Parameter uppercase: Use uppercase hex characters.
    func hexString(uppercase: Bool) -> String {
        if self.isZero {
            return "0"
        }

        // Use BigEndian for human-readable string. `BigUInt` semantics: strip leading zero bytes.
        return hexEncode(self.toBigEndian.drop { $0 == 0 }, uppercase: uppercase)
    }
}
