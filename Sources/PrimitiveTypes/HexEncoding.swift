// Pure-stdlib hex encoding helpers used by `BigUInt`, `FixedArray`, opcode descriptions,
// and tracing. Replaces `Foundation`'s `String(format:)` so production code in `Sources/`
// does not need to `import Foundation`.
//
// All helpers go through `String(decoding: bytes, as: UTF8.self)` (Swift stdlib, Swift 4+).

/// ASCII bytes for lowercase hex digits `0..f`.
@usableFromInline
internal let hexTableLower: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, // '0'..'7'
    0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, // '8', '9', 'a'..'f'
]

/// ASCII bytes for uppercase hex digits `0..F`.
@usableFromInline
internal let hexTableUpper: [UInt8] = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, // '0'..'7'
    0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, // '8', '9', 'A'..'F'
]

/// Encode a `UInt8` as two hex ASCII bytes (high nibble first).
@inlinable @inline(__always)
public func hexByteAscii(_ b: UInt8, uppercase: Bool) -> (UInt8, UInt8) {
    let table = uppercase ? hexTableUpper : hexTableLower
    return (table[Int(b >> 4)], table[Int(b & 0x0F)])
}

/// Encode an arbitrary `[UInt8]` byte sequence to a hex `String`, in order.
/// Each input byte produces two ASCII hex characters; result length = `bytes.count * 2`.
@inlinable
public func hexEncode<S: Sequence>(_ bytes: S, uppercase: Bool) -> String where S.Element == UInt8 {
    let table = uppercase ? hexTableUpper : hexTableLower
    var out: [UInt8] = []
    out.reserveCapacity(bytes.underestimatedCount * 2)
    for byte in bytes {
        out.append(table[Int(byte >> 4)])
        out.append(table[Int(byte & 0x0F)])
    }
    return String(decoding: out, as: UTF8.self)
}

/// Encode a `UInt64` to a hex `String` without leading zeros (matches `printf("%x")`).
/// Returns `"0"` for `value == 0`.
@inlinable
public func hexEncodeNoPad(_ value: UInt64, uppercase: Bool) -> String {
    if value == 0 { return "0" }
    let table = uppercase ? hexTableUpper : hexTableLower
    var out: [UInt8] = []
    out.reserveCapacity(16)
    var v = value
    while v != 0 {
        out.append(table[Int(v & 0x0F)])
        v >>= 4
    }
    out.reverse()
    return String(decoding: out, as: UTF8.self)
}
