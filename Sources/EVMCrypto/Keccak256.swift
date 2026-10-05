import PrimitiveTypes

#if TINY_KECCAK
/// Keccak-256 as used by the EVM: a 136-byte rate with the original `0x01` padding, not SHA3's `0x06`.
public enum Keccak256 {
    /// Sponge rate in bytes for a 256-bit output.
    private static let rate = 136

    private static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001, 0x0000_0000_0000_8082, 0x8000_0000_0000_808a, 0x8000_0000_8000_8000,
        0x0000_0000_0000_808b, 0x0000_0000_8000_0001, 0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
        0x0000_0000_0000_008a, 0x0000_0000_0000_0088, 0x0000_0000_8000_8009, 0x0000_0000_8000_000a,
        0x0000_0000_8000_808b, 0x8000_0000_0000_008b, 0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
        0x8000_0000_0000_8002, 0x8000_0000_0000_0080, 0x0000_0000_0000_800a, 0x8000_0000_8000_000a,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8080, 0x0000_0000_8000_0001, 0x8000_0000_8000_8008,
    ]

    /// ρ rotation offsets in the π lane order below.
    private static let rotations: [UInt64] = [
        1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
    ]

    /// π lane permutation, starting from lane 1.
    private static let lanes: [Int] = [
        10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
    ]

    /// Computes the EVM Keccak-256 digest of `input`.
    ///
    /// - Parameter input: Bytes that must remain readable and unchanged for the duration of the call.
    ///   No alignment is required. An empty buffer may have a `nil` base address.
    ///   The buffer is neither modified nor retained.
    /// - Returns: The 32-byte Keccak-256 digest, not the standardized SHA3-256 digest.
    public static func hash(_ input: UnsafeRawBufferPointer) -> H256 {
        withUnsafeTemporaryAllocation(of: UInt64.self, capacity: 25) { state in
            state.initialize(repeating: 0)

            var offset = 0
            while input.count - offset >= Self.rate {
                Self.absorb(input, at: offset, into: state)
                Self.permute(state)
                offset += Self.rate
            }

            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Self.rate) { block in
                block.initialize(repeating: 0)
                let remaining = input.count - offset
                UnsafeMutableRawBufferPointer(block).copyMemory(from: UnsafeRawBufferPointer(rebasing: input[offset...]))
                // Multi-rate padding: the domain bit follows the data and the final bit closes the block.
                block[remaining] ^= 0x01
                block[Self.rate - 1] ^= 0x80
                Self.absorb(UnsafeRawBufferPointer(block), at: 0, into: state)
            }
            Self.permute(state)

            // The digest is the little-endian serialization of the first four lanes; `H256` stores big-endian words.
            return H256(
                l0: UInt64(bigEndian: state[0].littleEndian),
                l1: UInt64(bigEndian: state[1].littleEndian),
                l2: UInt64(bigEndian: state[2].littleEndian),
                l3: UInt64(bigEndian: state[3].littleEndian)
            )
        }
    }

    /// XORs one rate-sized block of `input` into the state lanes.
    private static func absorb(_ input: UnsafeRawBufferPointer, at offset: Int, into state: UnsafeMutableBufferPointer<UInt64>) {
        for lane in 0 ..< rate / 8 {
            state[lane] ^= UInt64(littleEndian: input.loadUnaligned(fromByteOffset: offset + lane * 8, as: UInt64.self))
        }
    }

    /// Keccak-f[1600]: 24 rounds of θ, ρ, π, χ and ι.
    private static func permute(_ state: UnsafeMutableBufferPointer<UInt64>) {
        for round in 0 ..< 24 {
            let c0 = state[0] ^ state[5] ^ state[10] ^ state[15] ^ state[20]
            let c1 = state[1] ^ state[6] ^ state[11] ^ state[16] ^ state[21]
            let c2 = state[2] ^ state[7] ^ state[12] ^ state[17] ^ state[22]
            let c3 = state[3] ^ state[8] ^ state[13] ^ state[18] ^ state[23]
            let c4 = state[4] ^ state[9] ^ state[14] ^ state[19] ^ state[24]
            let d0 = c4 ^ Self.rotateLeft(c1, 1)
            let d1 = c0 ^ Self.rotateLeft(c2, 1)
            let d2 = c1 ^ Self.rotateLeft(c3, 1)
            let d3 = c2 ^ Self.rotateLeft(c4, 1)
            let d4 = c3 ^ Self.rotateLeft(c0, 1)
            for row in stride(from: 0, to: 25, by: 5) {
                state[row] ^= d0
                state[row + 1] ^= d1
                state[row + 2] ^= d2
                state[row + 3] ^= d3
                state[row + 4] ^= d4
            }

            var carried = state[1]
            for step in 0 ..< 24 {
                let lane = Self.lanes[step]
                let next = state[lane]
                state[lane] = Self.rotateLeft(carried, Self.rotations[step])
                carried = next
            }

            for row in stride(from: 0, to: 25, by: 5) {
                let a0 = state[row]
                let a1 = state[row + 1]
                let a2 = state[row + 2]
                let a3 = state[row + 3]
                let a4 = state[row + 4]
                state[row] = a0 ^ (~a1 & a2)
                state[row + 1] = a1 ^ (~a2 & a3)
                state[row + 2] = a2 ^ (~a3 & a4)
                state[row + 3] = a3 ^ (~a4 & a0)
                state[row + 4] = a4 ^ (~a0 & a1)
            }

            state[0] ^= Self.roundConstants[round]
        }
    }

    @inline(__always)
    private static func rotateLeft(_ value: UInt64, _ count: UInt64) -> UInt64 {
        (value << count) | (value >> (64 - count))
    }
}
#else
import CryptoSwift

/// The default EVM Keccak-256 implementation; the `TinyKeccak` trait selects the native implementation.
public enum Keccak256 {
    /// Computes the EVM Keccak-256 digest of `input`.
    ///
    /// - Parameter input: Bytes that must remain readable and unchanged for the duration of the call.
    ///   No alignment is required. An empty buffer may have a `nil` base address.
    ///   The buffer is neither modified nor retained.
    /// - Returns: The 32-byte Keccak-256 digest, not the standardized SHA3-256 digest.
    public static func hash(_ input: UnsafeRawBufferPointer) -> H256 {
        H256(from: SHA3(variant: .keccak256).calculate(for: Array(input)))
    }
}
#endif
