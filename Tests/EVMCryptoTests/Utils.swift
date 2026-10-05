import EVMCrypto
import Foundation
import PrimitiveTypes

/// Decodes an even-length hex string; the KAT files use uppercase digits.
func hexBytes(_ hex: String) -> [UInt8] {
    precondition(hex.count % 2 == 0, "Hex strings must have an even length.")
    var bytes: [UInt8] = []
    bytes.reserveCapacity(hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        bytes.append(UInt8(hex[index ..< next], radix: 16)!)
        index = next
    }
    return bytes
}

/// A message/digest pair from the Keccak team's known-answer test files.
struct KATVector {
    let message: [UInt8]
    let digest: H256
}

/// Readers for the fixtures copied from the Keccak team's `KeccakKAT-3.zip` archive.
enum KeccakKAT {
    /// Reads a fixture file by name; the test bundle ships every fixture, so lookup cannot fail.
    static func fixture(_ name: String) -> [Substring] {
        let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")!
        return try! String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    }

    /// Parses `Len`/`Msg`/`MD` entries; `Len` is in bits and only byte-aligned entries are kept.
    static func vectors(_ name: String) -> [KATVector] {
        var vectors: [KATVector] = []
        var bits = 0
        var message: [UInt8] = []
        for line in fixture(name) {
            if line.hasPrefix("Len = ") {
                bits = Int(line.dropFirst(6))!
            } else if line.hasPrefix("Msg = ") {
                message = hexBytes(String(line.dropFirst(6)))
            } else if line.hasPrefix("MD = "), bits % 8 == 0 {
                // The empty message is written as `00`, so the byte count comes from `Len`.
                let digest = try! H256.fromString(hex: String(line.dropFirst(5))).get()
                vectors.append(KATVector(message: Array(message.prefix(bits / 8)), digest: digest))
            }
        }
        return vectors
    }

    /// Parses the Monte Carlo seed and its 100 checkpoint digests.
    static func monteCarlo(_ name: String) -> (seed: [UInt8], checkpoints: [H256]) {
        var seed: [UInt8] = []
        var checkpoints: [H256] = []
        for line in fixture(name) {
            if line.hasPrefix("Seed = ") {
                seed = hexBytes(String(line.dropFirst(7)))
            } else if line.hasPrefix("MD = ") {
                checkpoints.append(try! H256.fromString(hex: String(line.dropFirst(5))).get())
            }
        }
        return (seed, checkpoints)
    }

    /// Parses the `Repeat`/`Text`/`MD` recipe of an extremely long message.
    static func extremelyLong(_ name: String) -> (repetitions: Int, text: [UInt8], digest: H256) {
        var repetitions = 0
        var text: [UInt8] = []
        var digest = H256.ZERO
        for line in fixture(name) {
            if line.hasPrefix("Repeat = ") {
                repetitions = Int(line.dropFirst(9))!
            } else if line.hasPrefix("Text = ") {
                text = Array(line.dropFirst(7).utf8)
            } else if line.hasPrefix("MD = ") {
                digest = try! H256.fromString(hex: String(line.dropFirst(5))).get()
            }
        }
        return (repetitions, text, digest)
    }
}

/// Hashes `bytes` through the raw-buffer API at the given alignment offset within a padded copy.
func keccak256(_ bytes: [UInt8], alignment: Int = 0) -> H256 {
    let padded = [UInt8](repeating: 0xEE, count: alignment) + bytes + [0xEE]
    return padded.withUnsafeBytes {
        Keccak256.hash(UnsafeRawBufferPointer(rebasing: $0[alignment ..< alignment + bytes.count]))
    }
}
