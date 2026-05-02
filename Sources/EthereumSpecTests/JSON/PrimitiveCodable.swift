import Foundation
import PrimitiveTypes

// MARK: - Decodable conformances for primitive types
//
// These conformances are *retroactive*: the types live in `PrimitiveTypes`, the protocol
// in `Swift`/`Foundation`. They are scoped to the test-runner JSON shape — short hex,
// `0x` prefix, left-padding — so the core `PrimitiveTypes` module stays minimal.

extension U256: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        do {
            self = try HexParser.parseU256(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex U256 value '\(raw)': \(error)"
            )
        }
    }
}

extension U128: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        do {
            self = try HexParser.parseU128(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex U128 value '\(raw)': \(error)"
            )
        }
    }
}

extension H160: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        do {
            self = try HexParser.parseH160(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex H160 (address) value '\(raw)': \(error)"
            )
        }
    }
}

extension H256: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        do {
            self = try HexParser.parseH256(raw)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid hex H256 value '\(raw)': \(error)"
            )
        }
    }
}
