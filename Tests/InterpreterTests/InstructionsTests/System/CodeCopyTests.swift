@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCodeCopySpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 1)

    override class func spec() {
        describe("Instruction CODECOPY") {
            it("with OutOfGas result for size=1") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack underflow errors is as expected") {
                var m = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m1 = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m2 = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m2.stack.push(value: U256(from: 2))
                let _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("size = 0") {
                var m = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m.stack.push(value: U256(from: 0))
                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas memory overflow for Size") {
                var m = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m.stack.push(value: U256(from: UInt64.max / 2))
                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas memory overflow for Offset") {
                var m = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: UInt64.max))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas overflow for resized memoryGasCost") {
                var m = TestMachine.machine(opcode: Opcode.CODECOPY, gasLimit: 10)
                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 96))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(28))
            }

            it("MemoryOperation error - CopyDataLimitExceeded") {
                var m = TestMachine.machine(opcodes: [Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.CODECOPY], gasLimit: 100, memoryLimit: 4)
                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.MemoryOperation(.CopyDataLimitExceeded)))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(78))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(10))
            }

            it("success") {
                var m = TestMachine.machine(opcodes: [Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.CODECOPY], gasLimit: 100)
                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 4))
                let _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let res = m.memory.get(offset: 31, size: 5)
                expect(res).to(equal([0, 91, 91, 57, 0]))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(78))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(10))
            }
        }
    }
}
