import Foundation
import PrimitiveTypes

/// EIP-7702 (Prague) helpers used by the test runner.
///
/// Mirrors `aurora-evm::evm-tests::types::eip_7702`.
public enum Eip7702 {
    /// Authorization tuple magic byte. Hashed with the RLP body to produce the signing hash.
    public static let MAGIC: UInt8 = 0x05

    /// `secp256k1n / 2`. Per EIP-2, signatures with `s > SECP256K1N_HALF` are rejected.
    /// Stored big-endian-LE-tuple-mirroring-Rust to allow parity-checks.
    /// Concrete bytes: `0x7fff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_5d57_6e73_57a4_501d_dfe9_2f46_681b_20a0`
    public static let SECP256K1N_HALF: U256 = U256(from: [
        0xDFE9_2F46_681B_20A0,
        0x5D57_6E73_57A4_501D,
        0xFFFF_FFFF_FFFF_FFFF,
        0x7FFF_FFFF_FFFF_FFFF,
    ])
}

/// Raw EIP-7702 authorization tuple from the JSON `authorizationList`.
public struct AuthorizationItem: Equatable, Sendable {
    public let chainId: U256
    public let address: H160
    public let nonce: U256
    public let r: U256
    public let s: U256
    public let v: U256
    public let signer: H160?
}

extension AuthorizationItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case chainId, address, nonce, r, s, v, signer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chainId = try c.decode(U256.self, forKey: .chainId)
        self.address = try c.decode(H160.self, forKey: .address)
        self.nonce = try c.decode(U256.self, forKey: .nonce)
        self.r = try c.decode(U256.self, forKey: .r)
        self.s = try c.decode(U256.self, forKey: .s)
        self.v = try c.decode(U256.self, forKey: .v)
        self.signer = try c.decodeIfPresent(H160.self, forKey: .signer)
    }
}

/// JSON `authorizationList` is a plain array of `AuthorizationItem`.
public typealias AuthorizationList = [AuthorizationItem]

/// `chainId / address / nonce` triple that goes into the signing hash.
public struct Authorization7702: Equatable, Sendable {
    public let chainId: U256
    public let address: H160
    public let nonce: UInt64

    public init(chainId: U256, address: H160, nonce: UInt64) {
        self.chainId = chainId
        self.address = address
        self.nonce = nonce
    }
}

/// EIP-7702 signed authorization. `recoverAddress()` is **stubbed** in this phase —
/// it requires secp256k1 ECDSA recovery which is not yet wired into Swift.
///
/// TODO(secp256k1): implement signature recovery here. Approaches:
///   - Vendor a small secp256k1 implementation
///   - Add a Swift dependency such as `swift-secp256k1` (Bitcoin Core wrapper)
///   - Bridge to Apple's CryptoKit (lacks secp256k1; would need separate library)
/// Until then, every state test that exercises EIP-7702 will be reported as
/// `skipped: secp256k1 recovery not implemented` rather than passed.
public struct SignedAuthorization: Equatable, Sendable {
    public let chainId: U256
    public let address: H160
    public let nonce: UInt64
    public let r: U256
    public let s: U256
    public let v: Bool

    public init(chainId: U256, address: H160, nonce: UInt64, r: U256, s: U256, v: Bool) {
        self.chainId = chainId
        self.address = address
        self.nonce = nonce
        self.r = r
        self.s = s
        self.v = v
    }

    public enum RecoveryError: Error, Equatable {
        case notImplemented
    }

    public func recoverAddress() throws -> H160 {
        throw RecoveryError.notImplemented
    }
}
