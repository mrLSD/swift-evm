@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionRevertSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 1, memoryLimit: 1024, HardFork: .Byzantium)
    @MainActor
    static let machine = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, HardFork: .Byzantium)

    override class func spec() {
        describe("Instruction REVERT") {
            it("with OutOfGas result for index=0") {
                 let m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 33))
                let _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(18))
            }

            it("check stack underflow errors is as expected") {
                 let m1 = Self.machine
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                 let m2 = Self.machine
                let _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack Int failure is as expected") {
                 let m1 = Self.machine
                let _ = m1.stack.push(value: U256(from: 1))
                let _ = m1.stack.push(value: U256(from: [1, 1, 0, 0]))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                 let m2 = Self.machine
                let _ = m2.stack.push(value: U256(from: [1, 1, 0, 0]))
                let _ = m2.stack.push(value: U256(from: 1))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check hard fork") {
                 let m1 = TestMachine.machine(opcodes: [Opcode.REVERT], gasLimit: 100, memoryLimit: 1024, HardFork: .SpuriousDragon)
                let _ = m1.stack.push(value: U256(from: 32))
                let _ = m1.stack.push(value: U256(from: 33))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))
            }

            it("Success") {
                 let m = Self.machine

                let _ = m.stack.push(value: U256(from: 32))
                let _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Revert)))
                expect(m.returnRange).to(equal(33 ..< 33 + 32))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(82))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(18))
            }
        }
    }
}
