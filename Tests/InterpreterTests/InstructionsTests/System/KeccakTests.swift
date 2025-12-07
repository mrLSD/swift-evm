@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionKeccakSpec: QuickSpec {
    override class func spec() {
        describe("Instruction KECCAK (SHA3)") {
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

                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m1.gas.remaining).to(equal(1000)) // No gas spent before check

                // Case 2: Memory Offset exceeds Int/UInt64 max
                // Note: Size is checked first, then gas recorded, then offset checked.
                // We need enough gas to pass the initial cost check to reach the offset check.
                let m2 = TestMachine.machine(data: [], opcode: Opcode.SHA3, gasLimit: 1000)
                _ = m2.stack.push(value: U256(from: 0)) // Size
                _ = m2.stack.push(value: U256(from: [1, 1, 0, 0])) // Huge Offset
                m2.evalLoop()

                expect(m2.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                // Gas should be deducted for the operation (Base 30 + 0 dynamic) because size check passed
                expect(m2.gas.remaining).to(equal(970))
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

                let expected = try! U256.fromString(hex: "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470").get()
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
