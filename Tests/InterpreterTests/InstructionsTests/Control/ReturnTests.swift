@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionReturnSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.RETURN, gasLimit: 100)

    override class func spec() {
        describe("Instruction RETURN") {
            it("with OutOfGas result for index=0") {
                let m = TestMachine.machine(opcode: Opcode.RETURN, gasLimit: 1)

                _ = m.stack.push(value: U256(from: 33))
                _ = m.stack.push(value: U256(from: 32))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(9))
            }

            it("check stack underflow errors is as expected") {
                let m1 = Self.machine
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = Self.machine
                _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack Int failure is as expected") {
                let m1 = Self.machine
                _ = m1.stack.push(value: U256(from: 1))
                _ = m1.stack.push(value: U256(from: [1, 1, 0, 0]))
                m1.evalLoop()

                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m1.gas.remaining).to(equal(100))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = Self.machine
                _ = m2.stack.push(value: U256(from: [1, 1, 0, 0]))
                _ = m2.stack.push(value: U256(from: 1))
                m2.evalLoop()

                expect(m2.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m2.gas.remaining).to(equal(100))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("Success") {
                let m = Self.machine

                _ = m.stack.push(value: U256(from: 32))
                _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Return))))
                expect(m.returnRange).to(equal(33 ..< 33 + 32))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(91))
                expect(m.gas.memoryGas.numWords).to(equal(3))
                expect(m.gas.memoryGas.gasCost).to(equal(9))
            }
        }
    }
}
