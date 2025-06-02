
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MStoreSpec: QuickSpec {
    override class func spec() {
        describe("Instruction MSTORE") {
            it("with OutOfGas result for index=0") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE, gasLimit: 1)

                let _ = m.stack.push(value: U256(from: 0))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack underflow errors is as expected") {
                let m1 = TestMachine.machine(opcode: Opcode.MSTORE, gasLimit: 10)
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(7))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = TestMachine.machine(opcode: Opcode.MSTORE, gasLimit: 10)
                let _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(7))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas overflow for resized memoryGasCost") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE, gasLimit: 10)
                // Value
                let _ = m.stack.push(value: U256(from: 1))
                // Index
                let _ = m.stack.push(value: U256(from: 97))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
                expect(m.gas.memoryGas.numWords).to(equal(5))
                expect(m.gas.memoryGas.gasCost).to(equal(40))
            }

            it("error MemoryOperation copyLimitExceeded") {
                let m = TestMachine.machine(opcodes: [Opcode.MSTORE], gasLimit: 100, memoryLimit: 100)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 100))
                m.evalLoop()

                expect(m.machineStatus)
                    .to(equal(Machine.MachineStatus.Exit(.Error(.MemoryOperation(.SetLimitExceeded)))))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(57))
                expect(m.gas.memoryGas.numWords).to(equal(5))
                expect(m.gas.memoryGas.gasCost).to(equal(40))
            }

            it("check stack Int failure is as expected") {
                let m = TestMachine.machine(opcodes: [Opcode.MSTORE], gasLimit: 100, memoryLimit: 100)
                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: [1, 1, 0, 0]))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(97))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("success") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE, gasLimit: 100)
                var value = [UInt8](repeating: 0, count: 32)
                value.replaceSubrange(0 ..< 14, with: [UInt8](repeating: 3, count: 14))

                let _ = m.stack.push(value: U256.fromBigEndian(from: value))
                let _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let resVal: [UInt8] = m.memory.get(offset: 30, size: 18)

                var expectedValue = [UInt8](repeating: 0, count: 16)
                expectedValue.replaceSubrange(3 ... 14, with: [UInt8](repeating: 3, count: 14))
                expect(resVal).to(equal(expectedValue))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(79))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(18))
            }
        }
    }
}
