/// Fixed array represent numbers based on fixed  bytes (`UInt8`) array
public protocol FixedArray: CustomStringConvertible, Equatable, Sendable {
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

    /// Create `FixedArray` from hex `String`. Returns Result type
    static func fromString(hex value: String) -> Result<Self, HexStringError>

    /// Encode to hex string with lowercase characters.
    func encodeHexLower() -> String

    /// Encode to hex string with uppercase characters.
    func encodeHexUpper() -> String

    /// Encode to hex string.
    /// - Parameter uppercase: Use uppercase hex characters.
    func hexString(uppercase: Bool) -> String
}

/// Implementation of common `FixedArray` functionality.
///
/// `isZero` and `==` are specialized per concrete type (`H160`, `H256`) to operate on stored
/// fields directly - see those files. They are deliberately not provided here as protocol-extension
/// defaults to avoid the `BYTES` array allocation on every call.
public extension FixedArray {
    /// Create `FixedArray` from hex `String`. Returns Result type
    static func fromString(hex value: String) -> Result<Self, HexStringError> {
        let hex = value.hasPrefix("0x") || value.hasPrefix("0X")
            ? String(value.dropFirst(2))
            : value

        // FixedArray (H160/H256) logic is STRICT.
        // It iterates exactly `numberBytes` times consuming 2 chars.
        // If string is shorter or longer, it fails.
        let expectedLength = Int(numberBytes) * 2

        if hex.count != expectedLength {
            return .failure(.InvalidStringLength)
        }

        var byteArray: [UInt8] = []
        byteArray.reserveCapacity(Int(numberBytes))

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index ..< nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                return .failure(.InvalidHexCharacter(byteString))
            }
            byteArray.append(byte)
            index = nextIndex
        }

        return .success(Self(from: byteArray))
    }
}

/// Implementation of `CustomStringConvertible`
public extension FixedArray {
    /// Canonical string representation (lowercase hex, full length with leading zeros)
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
        // FixedArray (H160/H256) logic:
        // Never strip leading zeros. Always return full length string.

        let bytes = self.BYTES
        let format = uppercase ? "%02X" : "%02x"

        return bytes
            .map { String(format: format, $0) }
            .joined()
    }
}
