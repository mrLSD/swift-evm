#if TINY_KECCAK
import CryptoSwift
#endif
import EVMCrypto
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class Keccak256Spec: QuickSpec {
    override class func spec() {
        describe("Keccak256") {
            it("hashes an empty raw buffer with a nil base address") {
                let input = UnsafeRawBufferPointer(start: nil, count: 0)
                let digest = Keccak256.hash(input)
                expect(digest).to(equal(H256.KECCAK_EMPTY))
            }

            context("Keccak team known-answer tests") {
                // Opt-in for release runs: the manual CI workflow sets the variable to 1; ordinary runs stay fast.
                if ProcessInfo.processInfo.environment["EVM_KECCAK_EXTREMELY_LONG_KAT"] == "1" {
                    it("matches ExtremelyLongMsgKAT_256 for one GiB") {
                        let recipe = KeccakKAT.extremelyLong("ExtremelyLongMsgKAT_256")
                        // Validate the official recipe before allocating the one-GiB buffer.
                        guard recipe.repetitions == 16_777_216, recipe.text.count == 64 else {
                            fail("ExtremelyLongMsgKAT_256 requires 16777216 repetitions of 64 bytes.")
                            return
                        }
                        var message = [UInt8](repeating: 0, count: recipe.repetitions * recipe.text.count)
                        message.withUnsafeMutableBytes { output in
                            recipe.text.withUnsafeBytes { input in
                                for offset in stride(from: 0, to: output.count, by: input.count) {
                                    UnsafeMutableRawBufferPointer(rebasing: output[offset ..< offset + input.count])
                                        .copyMemory(from: input)
                                }
                            }
                        }
                        let actual = message.withUnsafeBytes { Keccak256.hash($0) }
                        expect(actual).to(equal(recipe.digest))
                    }
                }

                it("matches ShortMsgKAT_256 for every byte length below 256 at every alignment") {
                    let vectors = KeccakKAT.vectors("ShortMsgKAT_256")
                    expect(vectors.count).to(equal(256))
                    expect(vectors.map(\.message.count)).to(equal(Array(0 ... 255)))
                    for (index, vector) in vectors.enumerated() {
                        for alignment in 0 ... 7 {
                            let actual = keccak256(vector.message, alignment: alignment)
                            expect(actual).to(equal(vector.digest), description: "entry=\(index), alignment=\(alignment)")
                        }
                    }
                }

                it("matches LongMsgKAT_256 for multi-block messages at every alignment") {
                    let vectors = KeccakKAT.vectors("LongMsgKAT_256")
                    expect(vectors.count).to(equal(65))
                    expect(vectors.map(\.message.count)).to(equal((0 ... 64).map { 256 + 63 * $0 }))
                    for (index, vector) in vectors.enumerated() {
                        for alignment in 0 ... 7 {
                            let actual = keccak256(vector.message, alignment: alignment)
                            expect(actual).to(equal(vector.digest), description: "entry=\(index), alignment=\(alignment)")
                        }
                    }
                }

                it("reproduces every MonteCarlo_256 checkpoint") {
                    // SHA-3 competition procedure: each of the 100 checkpoints follows 1000 iterations in which
                    // the next 1024-bit message is the digest followed by the first 768 bits of the current one.
                    let (seed, checkpoints) = KeccakKAT.monteCarlo("MonteCarlo_256")
                    expect(seed.count).to(equal(128))
                    expect(checkpoints.count).to(equal(100))
                    var message = seed
                    for (index, checkpoint) in checkpoints.enumerated() {
                        var digest = H256.ZERO
                        for _ in 0 ..< 1000 {
                            digest = keccak256(message)
                            message = digest.BYTES + message.prefix(96)
                        }
                        expect(digest).to(equal(checkpoint), description: "j=\(index)")
                    }
                }
            }

            context("vectors published by other implementations") {
                it("matches the empty-message constant") {
                    let digest = keccak256([])
                    expect(digest).to(equal(H256.KECCAK_EMPTY))
                }

                it("matches tiny-keccak and alloy-primitives test vectors") {
                    // tiny-keccak 2.0.2 tests/keccak.rs `string_keccak_256`.
                    let bytes = keccak256([1, 2, 3, 4, 5])
                    expect(bytes).to(equal(try! H256.fromString(hex: "7d87c5ea75f7378bb701e404c50639161af3eff66293e9f375b5f17eb50476f4").get()))
                    // alloy-primitives 1.7.2 src/utils/mod.rs `keccak256_hasher` and `test_hash_message` (EIP-191).
                    let hello = keccak256(Array("hello world".utf8))
                    expect(hello).to(equal(try! H256.fromString(hex: "47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad").get()))
                    let eip191 = keccak256(Array("\u{19}Ethereum Signed Message:\n11Hello World".utf8))
                    expect(eip191).to(equal(try! H256.fromString(hex: "a1de988600a42c4b4ab089b619297c17d53cffae5d5120d82d8a92d0bb3b78f2").get()))
                }

                it("matches CryptoSwift test vectors including one million bytes") {
                    // CryptoSwift 1.9.0 Tests/CryptoSwiftTests/DigestTests.swift `testKeccak*`.
                    let vectors: [(message: [UInt8], digest: String)] = [
                        (Array("abc".utf8), "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"),
                        (Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8),
                         "45d3b367a6904e6e8d502ee04999a7c27647f91fa845d456525fd352ae3d7371"),
                        (Array("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu".utf8),
                         "f519747ed599024f3882238e5ab43960132572b7345fbeb9a90769dafd21ad67"),
                        ([UInt8](repeating: 0x00, count: 136), "3a5912a7c5faa06ee4fe906253e339467a9ce87d533c65be3c15cb231cdb25f9"),
                        ([UInt8](repeating: 0x00, count: 272), "a8005c7a3125b6c3629b4181eca54d18721e41fef639718d205beb00b366ed7d"),
                        ([UInt8](repeating: 0x61, count: 1_000_000), "fadae6b49f129bbb812be8407b7b2894f34aecf6dbd1f9b0f0c7e9853098fc96"),
                    ]
                    for vector in vectors {
                        let actual = keccak256(vector.message)
                        let expected = try! H256.fromString(hex: vector.digest).get()
                        expect(actual).to(equal(expected), description: "length=\(vector.message.count)")
                    }
                }
            }

            #if TINY_KECCAK
            context("native implementation") {
                it("matches CryptoSwift for seeded messages at block boundaries and every alignment") {
                    let seed: UInt64 = 0x4B45_4343_414B
                    var state = seed
                    func next() -> UInt64 {
                        state = state &* 6_364_136_223_846_793_005 &+ 1
                        return state
                    }
                    let lengths = Array(0 ... 273) + [511, 512, 513, 1023, 1024, 1025, 4095, 4096, 4097, 10000]
                        + (0 ..< 32).map { _ in Int(next() % 16384) }
                    for length in lengths {
                        let payload = (0 ..< length).map { _ in UInt8(truncatingIfNeeded: next() >> 32) }
                        let expected = H256(from: SHA3(variant: .keccak256).calculate(for: payload))
                        for alignment in 0 ... 7 {
                            let actual = keccak256(payload, alignment: alignment)
                            expect(actual).to(equal(expected), description: "seed=\(seed), length=\(length), alignment=\(alignment)")
                        }
                    }
                }
            }
            #endif
        }
    }
}
