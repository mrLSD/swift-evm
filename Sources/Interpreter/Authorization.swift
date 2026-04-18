import PrimitiveTypes

/// `Authorization` contains already prepared data for EIP-7702.
/// - `authority`: is `ecrecovered` authority address.
/// - `address`: is delegation destination address.
/// - `nonce`: is the `nonce` value which `authority.nonce` should be equal.
/// - `isValid`: is the flag that indicates the validity of the authorization.
///   It is used to charge gas for each authorization item, but if it's invalid
///   it is excluded from the EVM `authority_list` flow.
public struct Authorization: Equatable, Sendable {
    public let authority: H160
    public let address: H160
    public let nonce: UInt64
    public let isValid: Bool

    /// Create a new `Authorization` with given `authority`, `address`, `nonce`, and `isValid` flag.
    public init(authority: H160, address: H160, nonce: UInt64, isValid: Bool) {
        self.authority = authority
        self.address = address
        self.nonce = nonce
        self.isValid = isValid
    }

    /// Returns `true` if `code` is a delegation designation.
    /// Format: `0xef0100 ++ address`, always 23 bytes.
    public static func isDelegated(code: [UInt8]) -> Bool {
        return code.count == 23 &&
            code[0] == 0xef &&
            code[1] == 0x01 &&
            code[2] == 0x00
    }

    /// Get `authority` delegated `address`.
    /// It checks if the code is a delegation designation (EIP-7702).
    public static func getDelegatedAddress(_ code: [UInt8]) -> H160? {
        guard isDelegated(code: code) else {
            return nil
        }
        // Extract 20 bytes starting from index 3
        let addressBytes = Array(code[3 ..< 23])
        return H160(from: addressBytes)
    }

    /// Returns the delegation code as composing: `0xef0100 ++ address`.
    /// Result code is always 23 bytes.
    public func delegationCode() -> [UInt8] {
        var code = [UInt8]()
        code.reserveCapacity(23)
        code.append(contentsOf: [0xef, 0x01, 0x00])
        code.append(contentsOf: address.BYTES)
        return code
    }
}

// MARK: - Default Implementation

public extension Authorization {
    /// Provides a default/zero instance of `Authorization`.
    static let `default` =
        Authorization(
            authority: .ZERO,
            address: .ZERO,
            nonce: 0,
            isValid: false
        )
}
