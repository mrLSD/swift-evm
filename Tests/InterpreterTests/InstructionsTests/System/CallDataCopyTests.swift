@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCallDataCopySpec: QuickSpec {
    override class func spec() {
        describe("Instruction CALLDATACOPY") {
            it("with OutOfGas result for size=1") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 1)

                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 3))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(3))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack underflow errors is as expected") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m1 = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m2 = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m2.stack.push(value: U256(from: 2))
                _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("data size = 0") {
                let m = TestMachine.machine(data: [], opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m.stack.push(value: U256(from: 0))
                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas memory overflow for Data Size") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m.stack.push(value: U256(from: UInt64.max / 2))
                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(3))
                expect(m.gas.remaining).to(equal(10))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas memory overflow for Data Offset") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: UInt64(Int.max)))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas overflow for resized memoryGasCost") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 10)
                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 96))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(12))
            }

            it("MemoryOperation error - CopyDataLimitExceeded") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
                let m = TestMachine.machine(data: callData, opcodes: [Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.JUMPDEST, Opcode.CALLDATACOPY], gasLimit: 100, memoryLimit: 4)
                _ = m.stack.push(value: U256(from: 3))
                _ = m.stack.push(value: U256(from: 2))
                _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.MemoryOperation(.CopyDataLimitExceeded)))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(82))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
            }

            it("check stack Int failure is as expected") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
                let m1 = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 100)
                _ = m1.stack.push(value: U256(from: 3))
                _ = m1.stack.push(value: U256(from: 4))
                _ = m1.stack.push(value: U256(from: [1, 1, 0, 0]))
                m1.evalLoop()

                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m1.gas.remaining).to(equal(94))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 100)
                _ = m2.stack.push(value: U256(from: 3))
                _ = m2.stack.push(value: U256(from: [1, 1, 0, 0]))
                _ = m2.stack.push(value: U256(from: 32))
                m2.evalLoop()

                expect(m2.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m2.gas.remaining).to(equal(94))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))

                let m3 = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 100)
                _ = m3.stack.push(value: U256(from: [1, 1, 0, 0]))
                _ = m3.stack.push(value: U256(from: 4))
                _ = m3.stack.push(value: U256(from: 32))
                m3.evalLoop()

                expect(m3.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m3.gas.remaining).to(equal(100))
                expect(m3.gas.memoryGas.numWords).to(equal(0))
                expect(m3.gas.memoryGas.gasCost).to(equal(0))
            }

            it("success") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATACOPY, gasLimit: 100)
                _ = m.stack.push(value: U256(from: 3))
                _ = m.stack.push(value: U256(from: 4))
                _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let res = m.memory.get(offset: 31, size: 5)
                expect(res).to(equal([0, 5, 6, 7, 0]))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(88))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
            }
        }
    }
}
