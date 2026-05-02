import Foundation
import PrimitiveTypes

// MARK: - Container helpers for shapes not covered by `Decodable` conformances
//
// `U256` / `H160` / `H256` decode automatically from a hex string. These helpers cover the
// shapes that need explicit handling:
//
// - hex-encoded bytes (`Vec<u8>`)        → `decodeHexBytes(forKey:)`
// - hex-encoded UInt8 / UInt64           → `decodeHexUInt8(forKey:)` / `decodeHexUInt64(forKey:)`
// - vector of hex blobs                  → `decodeHexBytesArray(forKey:)`
// - vector of hex U256                   → `decodeHexU256Array(forKey:)`
// - storage map `{hexkey: hexvalue}`     → `decodeStorageMap(forKey:)`

extension KeyedDecodingContainer {
    /// Decode `Vec<u8>` from a hex string. Returns `[]` for `"0x"`.
    func decodeHexBytes(forKey key: K) throws -> [UInt8] {
        let raw = try decode(String.self, forKey: key)
        do {
            return try HexParser.decodeBytes(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex byte string '\(raw)': \(error)"
            )
        }
    }

    /// Optional `Vec<u8>` decoded from hex. Missing keys → `nil`.
    func decodeHexBytesIfPresent(forKey key: K) throws -> [UInt8]? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        do {
            return try HexParser.decodeBytes(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex byte string '\(raw)': \(error)"
            )
        }
    }

    /// Decode a UInt8 from hex (e.g. tx type byte).
    func decodeHexUInt8(forKey key: K) throws -> UInt8 {
        let raw = try decode(String.self, forKey: key)
        do {
            return try HexParser.parseUInt8(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex UInt8 '\(raw)': \(error)"
            )
        }
    }

    func decodeHexUInt8IfPresent(forKey key: K) throws -> UInt8? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        do {
            return try HexParser.parseUInt8(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex UInt8 '\(raw)': \(error)"
            )
        }
    }

    /// Decode a UInt64 from hex.
    func decodeHexUInt64(forKey key: K) throws -> UInt64 {
        let raw = try decode(String.self, forKey: key)
        do {
            return try HexParser.parseUInt64(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex UInt64 '\(raw)': \(error)"
            )
        }
    }

    func decodeHexUInt64IfPresent(forKey key: K) throws -> UInt64? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        do {
            return try HexParser.parseUInt64(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self,
                debugDescription: "Invalid hex UInt64 '\(raw)': \(error)"
            )
        }
    }

    /// Decode a `Vec<Vec<u8>>` (array of hex strings).
    func decodeHexBytesArray(forKey key: K) throws -> [[UInt8]] {
        let raws = try decode([String].self, forKey: key)
        return try raws.map { raw in
            do {
                return try HexParser.decodeBytes(raw)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: self,
                    debugDescription: "Invalid hex byte string in array '\(raw)': \(error)"
                )
            }
        }
    }

    /// Decode a `Vec<U256>` (array of hex strings).
    func decodeHexU256Array(forKey key: K) throws -> [U256] {
        let raws = try decode([String].self, forKey: key)
        return try raws.map { raw in
            do {
                return try HexParser.parseU256(raw)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: self,
                    debugDescription: "Invalid hex U256 in array '\(raw)': \(error)"
                )
            }
        }
    }

    /// Decode a storage map `{ hexKey: hexValue }` → `[H256: H256]`.
    /// Both keys and values are tolerant H256 (left-padded short hex).
    func decodeStorageMap(forKey key: K) throws -> [H256: H256] {
        let raw = try decode([String: String].self, forKey: key)
        var result: [H256: H256] = [:]
        result.reserveCapacity(raw.count)
        for (k, v) in raw {
            let hk: H256
            let hv: H256
            do {
                hk = try HexParser.parseH256(k)
                hv = try HexParser.parseH256(v)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: self,
                    debugDescription: "Invalid storage entry '\(k)':'\(v)': \(error)"
                )
            }
            result[hk] = hv
        }
        return result
    }
}
