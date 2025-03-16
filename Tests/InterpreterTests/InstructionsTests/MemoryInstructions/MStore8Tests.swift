
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MStore8Spec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 1)

    override class func spec() {
        describe("Instruction MSTORE8") {
            it("with OutOfGas result for index=0") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 0))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack underflow errors is as expected") {
                var m1 = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(7))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                var m2 = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                let _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(7))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas overflow for resized memoryGasCost") {
                var m = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                // Value
                let _ = m.stack.push(value: U256(from: 1))
                // Index
                let _ = m.stack.push(value: U256(from: 97))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(28))
            }

            it("error MemoryOperation copyLimitExceeded") {
                var m = TestMachine.machine(opcodes: [Opcode.MSTORE8], gasLimit: 100, memoryLimit: 100)

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 100))
                m.evalLoop()

                expect(m.machineStatus)
                    .to(equal(Machine.MachineStatus.Exit(.Error(.MemoryOperation(.SetLimitExceeded)))))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(69))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(28))
            }

            it("success") {
                var m = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 100)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let resVal: [UInt8] = m.memory.get(offset: 32, size: 3)

                expect(resVal).to(equal([0, 3, 0]))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(87))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(10))
            }
        }
    }
}
