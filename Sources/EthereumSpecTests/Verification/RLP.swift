import Foundation
import PrimitiveTypes

/// Minimal RLP (Recursive Length Prefix) encoder.
///
/// Implements only the encode-side primitives needed by the test runner:
///   - byte strings (`encodeBytes`)
///   - unsigned integers as big-endian-trimmed bytes (`encodeUInt`, `encodeU256`, `encodeUInt64`)
///   - lists of pre-encoded items (`encodeList`)
///
/// Reference: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
enum RLP {
    /// Encode a raw byte string.
    static func encodeBytes(_ bytes: [UInt8]) -> [UInt8] {
        // Single byte 0x00..0x7f → itself.
        if bytes.count == 1 && bytes[0] < 0x80 {
            return bytes
        }
        // Short string: 0..55 bytes
        if bytes.count <= 55 {
            return [UInt8(0x80 + bytes.count)] + bytes
        }
        // Long string: > 55 bytes
        let lenBytes = encodeBigEndianLength(UInt(bytes.count))
        return [UInt8(0xb7 + lenBytes.count)] + lenBytes + bytes
    }

    /// Encode a list of *already-encoded* items (concatenated payload).
    static func encodeList(_ items: [[UInt8]]) -> [UInt8] {
        let payload = items.flatMap { $0 }
        if payload.count <= 55 {
            return [UInt8(0xc0 + payload.count)] + payload
        }
        let lenBytes = encodeBigEndianLength(UInt(payload.count))
        return [UInt8(0xf7 + lenBytes.count)] + lenBytes + payload
    }

    /// Encode an unsigned integer as the minimal big-endian byte sequence (zero → empty string).
    /// Mirrors `rlp::Encodable for U256` in the parity-style RLP crate Rust uses.
    static func encodeU256(_ value: U256) -> [UInt8] {
        if value.isZero { return [0x80] }   // RLP empty string == zero
        let stripped = stripLeadingZeros(value.toBigEndian)
        return encodeBytes(stripped)
    }

    static func encodeUInt64(_ value: UInt64) -> [UInt8] {
        if value == 0 { return [0x80] }
        let bigEndian: [UInt8] = (0..<8).reversed().map { UInt8((value >> ($0 * 8)) & 0xff) }
        return encodeBytes(stripLeadingZeros(bigEndian))
    }

    /// Encode a fixed-width hash (no leading-zero stripping) as a byte string.
    static func encodeH256(_ value: H256) -> [UInt8] {
        encodeBytes(value.BYTES)
    }

    static func encodeH160(_ value: H160) -> [UInt8] {
        encodeBytes(value.BYTES)
    }

    // MARK: - helpers

    private static func stripLeadingZeros(_ bytes: [UInt8]) -> [UInt8] {
        if let first = bytes.firstIndex(where: { $0 != 0 }) {
            return Array(bytes[first...])
        }
        return []
    }

    private static func encodeBigEndianLength(_ length: UInt) -> [UInt8] {
        var v = length
        var bytes: [UInt8] = []
        while v > 0 {
            bytes.append(UInt8(v & 0xff))
            v >>= 8
        }
        return bytes.reversed()
    }
}

/// Convenience: RLP-encode a `TrieAccount` exactly as the Rust reference does. Mirrors
/// the `rlp::Encodable for TrieAccount` impl in
/// `aurora-evm::evm-tests::types::account_state::TrieAccount`:
/// 4-tuple if `code_version == 0`, else 5-tuple.
extension TrieAccount {
    func rlpEncoded() -> [UInt8] {
        let useShort = codeVersion.isZero
        var items: [[UInt8]] = [
            RLP.encodeU256(nonce),
            RLP.encodeU256(balance),
            RLP.encodeH256(storageRoot),
            RLP.encodeH256(codeHash)
        ]
        if !useShort { items.append(RLP.encodeU256(codeVersion)) }
        return RLP.encodeList(items)
    }
}
