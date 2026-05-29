import Foundation
import PrimitiveTypes

/// Hex string parsing tolerant of the conventions used by the Ethereum spec test JSON.
///
/// Mirrors the helpers in `aurora-evm/evm-tests/src/types/json_utils.rs`:
/// - strips `0x` / `0X` prefix
/// - left-pads odd-length hex with a single `0`
/// - left-pads decoded bytes with zeros up to the target width (`H160`/`H256`)
/// - rejects values wider than the target type
///
/// The intent is *bit-for-bit parity* with the Rust deserializers — the spec test corpus
/// encodes short integers like `"0x01"` for fields whose semantic type is `H256`, and
/// `"0x"` for an empty `U256`.
enum HexParser {
    /// Decode a hex string to raw bytes. Strips `0x` prefix; left-pads single odd nibble.
    /// Returns `[]` for `"0x"` / `""`.
    static func decodeBytes(_ value: String) throws -> [UInt8] {
        var hex = stripPrefix(value)
        if hex.isEmpty { return [] }
        if hex.count % 2 == 1 { hex = "0" + hex }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var i = hex.startIndex
        while i < hex.endIndex {
            let next = hex.index(i, offsetBy: 2)
            let pair = String(hex[i..<next])
            guard let byte = UInt8(pair, radix: 16) else {
                throw HexStringError.InvalidHexCharacter(pair)
            }
            bytes.append(byte)
            i = next
        }
        return bytes
    }

    /// Decode a hex string into a `U256`. Accepts up to 32 bytes; values wider than that
    /// throw `HexStringError.InvalidStringLength`. Empty hex parses as `U256.ZERO`.
    static func parseU256(_ value: String) throws -> U256 {
        let bytes = try decodeBytes(value)
        if bytes.count > 32 { throw HexStringError.InvalidStringLength }
        if bytes.isEmpty { return U256.ZERO }
        return U256.fromBigEndian(from: bytes)
    }

    /// Decode a hex string into a `U128`. Accepts up to 16 bytes.
    static func parseU128(_ value: String) throws -> U128 {
        let bytes = try decodeBytes(value)
        if bytes.count > 16 { throw HexStringError.InvalidStringLength }
        if bytes.isEmpty { return U128.ZERO }
        return U128.fromBigEndian(from: bytes)
    }

    /// Decode a hex string into a `H160`. Accepts ≤ 20 bytes; left-pads to exactly 20.
    static func parseH160(_ value: String) throws -> H160 {
        let bytes = try decodeBytes(value)
        if bytes.count > 20 { throw HexStringError.InvalidStringLength }
        if bytes.count == 20 { return H160(from: bytes) }
        var padded = [UInt8](repeating: 0, count: 20)
        padded.replaceSubrange((20 - bytes.count)..<20, with: bytes)
        return H160(from: padded)
    }

    /// Decode a hex string into a `H256`. Accepts ≤ 32 bytes; left-pads to exactly 32.
    /// Mirrors Rust `deserialize_h256_from_u256_str` — addresses and hashes in the
    /// corpus are routinely encoded as short integer hex (e.g. `"0x01"` → 32 bytes).
    static func parseH256(_ value: String) throws -> H256 {
        let bytes = try decodeBytes(value)
        if bytes.count > 32 { throw HexStringError.InvalidStringLength }
        if bytes.count == 32 { return H256(from: bytes) }
        var padded = [UInt8](repeating: 0, count: 32)
        padded.replaceSubrange((32 - bytes.count)..<32, with: bytes)
        return H256(from: padded)
    }

    /// Decode a hex string into a `UInt8`.
    static func parseUInt8(_ value: String) throws -> UInt8 {
        let bytes = try decodeBytes(value)
        if bytes.count > 1 { throw HexStringError.InvalidStringLength }
        return bytes.first ?? 0
    }

    /// Decode a hex string into a `UInt64`. Accepts ≤ 8 bytes.
    static func parseUInt64(_ value: String) throws -> UInt64 {
        let bytes = try decodeBytes(value)
        if bytes.count > 8 { throw HexStringError.InvalidStringLength }
        var result: UInt64 = 0
        for byte in bytes {
            result = (result << 8) | UInt64(byte)
        }
        return result
    }

    private static func stripPrefix(_ value: String) -> String {
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            return String(value.dropFirst(2))
        }
        return value
    }
}
