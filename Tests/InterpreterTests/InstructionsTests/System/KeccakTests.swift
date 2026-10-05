@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionKeccakSpec: QuickSpec {
    override class func spec() {
        describe("Instruction KECCAK (SHA3)") {
            context("memory ranges") {
                // CryptoSwift 1.9.0 reference vectors for byte[i] = (37*i + 11) mod 256.
                let vectors: [(length: Int, digest: String)] = [
                    (0, "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"),
                    (1, "60811857dd566889ff6255277d82526f2d9b3bbcb96076be22a5860765ac3d06"),
                    (7, "41af5ee4702c95c351bc338fbe25ee2190be60eba2087442a561b5c9a685f37b"),
                    (8, "f5eb524d25780543da47ded5467544ab9fb6d4a8bd9a6c9647db2e84ca2e0895"),
                    (31, "d061aba7d9d87cdc0b8a8e859ac74cdda6b0ea667ef7ead430c3d30ce38a4598"),
                    (32, "d064c972ea7cbd9f1237bbd922fd5f08ca57895c13bc9ea2b91913f7099809a1"),
                    (64, "52c1f4616862f9d5011ed6a2a77d89a2102e51ee7db2db045bb5fb267fba98d1"),
                    (135, "9b6deb2387c86783862216d0205051ba7d41fa4fa70a30e2abfe18ca94d22b22"),
                    (136, "b8717c6e7605ca3b5a0a94a147127679778a23a4324e53b910263673d0bfb55c"),
                    (137, "e2d9f409a6d575e1457f9d3f7436081485d5794bf84db179566eea07a8266e8d"),
                    (271, "082c1890ab04d225712c1871454aee54123aade62ca5937e5b609921ec21930b"),
                    (272, "79cacfd52db427ce7b9a771984a13387a6e31075bcc4716a5deddff6875c4e69"),
                    (273, "a0a3ace708ff419126bd75b3267766ba7c025b477c1216f30ad7a6d192997220"),
                    (511, "bc37240c723d13f1753b1a512136bb35c5546223ea5b3c16b9f310bcbb1c8c95"),
                    (512, "0ef15f90caea6a8e5264a17587fbe882a09c1333da268aa75008fa192d66ef50"),
                    (513, "8e23e1d706ca04ae5d70105ce5f1012d570cbd1658839d743b4a9eb03408b4a7"),
                    (1023, "ac72b7c9aafc660a583e535f1021c1716bd84af6f92bd947c884050dc82db009"),
                    (1024, "edcf460f06a93bdaa7f1808897880fd4f81f7e76036adbe8119514d8f9f6d786"),
                    (1025, "8cebb3845044cbc8a7ba97d986c66a495695f6dadf04e3ba78549128c11b9742"),
                    (4095, "701534bd3988a12c0705ed2100877597b5c77b5dacbe5ace2bd4241f6329506a"),
                    (4096, "9287eeba4e94e058f3f2b522de7d535b8f019a1a3fa27f11f693aff30f954b32"),
                    (4097, "dc1f6bee42ee7c4964e8782ff18c19af680be52068382fc0e0f6556487da84e2"),
                    (10000, "f4ec4a4dcb325cc2a10609dac1c3e3e3717741fce5d400d1ca3dc65ae9bd4d5c"),
                ]

                it("hashes the requested memory range through SHA3 and charges exact gas") {
                    for vector in vectors {
                        let payload = (0 ..< vector.length).map { UInt8(truncatingIfNeeded: $0 * 37 + 11) }
                        let offset = 3
                        let bytes = [UInt8](repeating: 0xEE, count: offset) + payload + [0xEE]
                        let m = TestMachine.machine(opcode: .SHA3, gasLimit: 100_000)
                        expect(m.memory.set(offset: 0, value: bytes, size: bytes.count)).to(beSuccess())
                        m.stackPush(value: U256(from: UInt64(vector.length)))
                        m.stackPush(value: U256(from: UInt64(offset)))
                        m.evalLoop()
                        let expected = try! U256.fromString(hex: vector.digest).get()
                        let words = UInt64((vector.length + 31) / 32)
                        let memoryWords = vector.length == 0 ? 0 : UInt64((offset + vector.length + 31) / 32)
                        let cost = 30 + 6 * words + 3 * memoryWords + memoryWords * memoryWords / 512
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([expected]), description: "length=\(vector.length)")
                        expect(m.gas.remaining).to(equal(100_000 - cost))
                        expect(m.memory.get(offset: 0, size: bytes.count)).to(equal(bytes))
                    }
                }
            }

            it("check stack underflow errors is as expected") {
                // Case 0: Empty stack
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                // Case 1: Only size on stack (missing offset)
                let m1 = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                _ = m1.stack.push(value: U256(from: 32)) // size
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("check stack Int failure is as expected for size and offset") {
                // Case 1: Size exceeds Int/UInt64 max (Platform dependent, usually 64-bit)
                let m1 = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 1000)
                _ = m1.stack.push(value: U256(from: [1, 1, 0, 0])) // Huge size
                _ = m1.stack.push(value: U256(from: 0)) // Offset
                m1.evalLoop()

                expect(m1.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m1.gas.remaining).to(equal(1000)) // No gas spent before check
            }

            it("check stack Int success is as expected for zero size and offset") {
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 1000)
                _ = m.stack.push(value: U256(from: 0)) // Size
                _ = m.stack.push(value: U256(from: [1, 1, 0, 0])) // Huge Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                // Gas should be deducted for the operation (Base 30 + 0 dynamic) because size check passed
                expect(m.gas.remaining).to(equal(970))
                expect(m.gas.memoryGas.gasCost).to(equal(0))

                let expected = U256.fromBigEndian(from: H256.KECCAK_EMPTY.BYTES)
                let result = try! m.stack.pop().get()
                expect(result).to(equal(expected))

                expect(m.stack.length).to(equal(0))
            }

            it("check OutOfGas on memory offset with non-zero size") {
                // Covers the `getMemoryIntOrFail(rawMemoryOffset)` branch in `keccak256`.
                // The branch is reachable only when size > 0 — for size == 0 the KECCAK_EMPTY
                // short-circuit returns before memoryOffset is validated.
                // size = 32 → keccak256Cost = 30 + 6*1 = 36. memoryOffset > Int.max → OutOfGas.
                // Memory expansion is NOT attempted (offset check fails before resize).
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 1000)
                _ = m.stack.push(value: U256(from: 32)) // Size (non-zero, bypasses KECCAK_EMPTY)
                _ = m.stack.push(value: U256(from: [1, 1, 0, 0])) // Huge memory offset (> Int.max)
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(964)) // 1000 - 36 (base 30 + 1 word * 6)
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("fails with OutOfGas if limit is less than Base Cost (30)") {
                // Base cost for KECCAK256 is 30
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 29)
                _ = m.stack.push(value: U256(from: 0)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(29)) // Atomic operation: all or nothing
            }

            it("fails with OutOfGas for dynamic word cost") {
                // Formula: 30 + 6 * ceil(size / 32)
                // Size 33 bytes = 2 words.
                // Cost: 30 + (6 * 2) = 42.
                // + Memory expansion cost (handled separately but checked sequentially)

                // Let's test just the operational cost first (ignoring memory expansion
                // by using 0 offset and pre-allocated memory logic implication, though
                // here we assume strict sequential check)

                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 41)
                _ = m.stack.push(value: U256(from: 33)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
            }

            it("fails with OutOfGas during memory expansion") {
                // Size: 32 bytes (1 word).
                // Op Cost: 30 + 6 = 36.
                // Memory Expansion: 1 word. Cost: 3 * 1 + (1*1)/512 = 3.
                // Total required: 39.

                // Give 38 gas. Enough for Op cost (36), not enough for Memory (3).
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 38)
                _ = m.stack.push(value: U256(from: 32)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                // Op cost (36) is recorded BEFORE memory resize.
                // So remaining should be 38 - 36 = 2.
                expect(m.gas.remaining).to(equal(2))

                // MemoryGas calculated the new cost (3) and updated itself,
                // but the deduction from main gas failed.
                expect(m.gas.memoryGas.gasCost).to(equal(3))
            }

            it("fails with OutOfGas for arithmetic overflow in cost calculation") {
                // Extremely large size that causes overflow in `keccak256Cost` calculation
                // even if it fits in Int64.
                // `costPerWord` calculation: size * multiple.
                // If we pass a size near Int.max, `costPerWord` will overflow.

                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100000)
                let hugeSize = U256(from: UInt64.max / 2) // Valid for stack pop, but causes calc issues

                _ = m.stack.push(value: hugeSize)
                _ = m.stack.push(value: U256(from: 0))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
            }

            it("successfully computes empty hash (size 0)") {
                // Empty Keccak-256: 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                _ = m.stack.push(value: U256(from: 0)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let expected = U256.fromBigEndian(from: H256.KECCAK_EMPTY.BYTES)
                let result = try! m.stack.pop().get()
                expect(result).to(equal(expected))

                expect(m.stack.length).to(equal(0))

                // Verify Gas
                // Cost: 30 (Base). Size 0 -> 0 words. Memory 0 -> 0 cost.
                // Total spent: 30. Remaining: 70.
                expect(m.gas.remaining).to(equal(70))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("successfully computes hash of 32 bytes (1 word)") {
                // We are hashing 32 bytes of zeros (since memory is zero-initialized).
                // Keccak-256(32 bytes of 0x00): 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563

                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                _ = m.stack.push(value: U256(from: 32)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                // Verify Result
                let result = try! m.stack.pop().get()
                let expected = try! U256.fromString(hex: "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563").get()
                expect(result).to(equal(expected))

                expect(m.stack.length).to(equal(0))

                // Verify Gas
                // Op Cost: 30 + 6 * 1 = 36.
                // Memory Cost: 32 bytes -> 1 word. 3*1 + 0 = 3.
                // Total spent: 39. Remaining: 61.
                expect(m.gas.remaining).to(equal(61))
                expect(m.gas.memoryGas.numWords).to(equal(1))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
            }

            it("successfully computes hash crossing word boundaries (33 bytes)") {
                // Size: 33 bytes (requires 2 words for Keccak calculation cost, and 2 words for memory expansion).
                // Hashing 33 bytes of 0x00.

                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                _ = m.stack.push(value: U256(from: 33)) // Size
                _ = m.stack.push(value: U256(from: 0)) // Offset
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                // Verify Result
                // keccak256(zerobytes(33))
                let result = try! m.stack.pop().get()
                let expected = try! U256.fromString(hex: "f39a869f62e75cf5f0bf914688a6b289caf2049435d8e68c5c5e6d05e44913f3").get()
                expect(result).to(equal(expected))

                expect(m.stack.length).to(equal(0))

                // Verify Gas
                // Op Cost: 30 + 6 * 2 (ceil(33/32)) = 42.
                // Memory Cost: 33 bytes -> 2 words. 3*2 + (4/512 -> 0) = 6.
                // Total spent: 48. Remaining: 52.
                expect(m.gas.remaining).to(equal(52))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
            }

            it("handles memory offset correctly (hashing from middle of memory)") {
                // We want to hash 32 bytes starting at offset 32.
                // Memory will expand to 64 bytes (2 words).
                // Bytes at [32...63] are also zero.

                let m = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 100)
                _ = m.stack.push(value: U256(from: 32)) // Size
                _ = m.stack.push(value: U256(from: 32)) // Offset (start at second word)
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                // Result should be hash of 32 zeros (same as previous test)
                let result = try! m.stack.pop().get()
                let expected = try! U256.fromString(hex: "290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563").get()
                expect(result).to(equal(expected))

                expect(m.stack.length).to(equal(0))

                // Verify Gas
                // Op Cost: 30 + 6 * 1 = 36.
                // Memory Cost: End index 64 -> 2 words. 3*2 + 0 = 6.
                // Total spent: 42. Remaining: 58.
                expect(m.gas.remaining).to(equal(58))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
            }
        }
    }
}
