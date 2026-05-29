import Foundation
import PrimitiveTypes

/// Bytewise lexicographic less-than over two byte arrays.
///
/// Implementation uses `memcmp`, which on every modern stdlib delegates to a SIMD-vectorised
/// kernel. Substantially faster than an element-wise Swift `zip`/`<` loop on the 20-/32-byte
/// keys this runner sorts.
///
/// Semantics match `Sequence`'s lexicographic order:
///   - first differing byte (compared *unsigned*) decides the ordering;
///   - if one buffer is a strict prefix of the other, the shorter is less;
///   - two equal buffers compare as not-less-than.
///
/// The function is **safe for empty inputs** — `withUnsafeBufferPointer.baseAddress`
/// is only force-unwrapped when both buffers are guaranteed non-empty.
@inline(__always)
internal func bytewiseLessThan(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    let n = Swift.min(lhs.count, rhs.count)
    if n == 0 { return lhs.count < rhs.count }
    return lhs.withUnsafeBufferPointer { lp in
        rhs.withUnsafeBufferPointer { rp in
            // Both arrays have count >= n > 0, so baseAddress is non-nil for both.
            let cmp = memcmp(lp.baseAddress!, rp.baseAddress!, n)
            return cmp != 0 ? cmp < 0 : lhs.count < rhs.count
        }
    }
}

extension Dictionary where Key: FixedArray {
    /// Return the dictionary's keys sorted by big-endian byte order.
    ///
    /// Materialises a single `Array` and sorts it in place — one allocation.
    @inline(__always)
    func keysSortedByBytes() -> [Key] {
        var keys = Array(self.keys)
        keys.sort { bytewiseLessThan($0.BYTES, $1.BYTES) }
        return keys
    }

    /// Return the dictionary's `(key, value)` pairs sorted by the key's big-endian bytes.
    ///
    /// Use this whenever the loop body needs both the key *and* the value — sorting tuples
    /// avoids a second `dict[key]` lookup per iteration (and the force-unwrap that usually
    /// comes with it). One allocation; in-place sort.
    @inline(__always)
    func pairsSortedByBytes() -> [(Key, Value)] {
        var pairs = Array(self)
        pairs.sort { bytewiseLessThan($0.0.BYTES, $1.0.BYTES) }
        return pairs
    }
}
