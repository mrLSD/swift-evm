@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionJumpSpec: QuickSpec {
    override class func spec() {
        describe("Instruction JUMP") {
            it("Correct JUMP") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x4, Opcode.JUMP.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.pc).to(equal(5))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("Invalid JUMP to PUSH1 range") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.JUMP.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidJump))))
                expect(m.pc).to(equal(2))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(9))
            }

            it("Invalid JUMP to non JUMPDEST opcode") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x3, Opcode.JUMP.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidJump))))
                expect(m.pc).to(equal(2))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(9))
            }

            it("JUMPDEST too large") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH8.rawValue, 0x80, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, Opcode.JUMP.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m.pc).to(equal(9))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(9))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.JUMP, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("with OutOfGas result for JUMPDEST") {
                let m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x4, Opcode.JUMP.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 11)

                m.evalLoop()
                expect(m.pc).to(equal(4))
                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
            }

            it("check stack underflow for empty stack") {
                let m = TestMachine.machine(opcode: Opcode.JUMP, gasLimit: 10)

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
        }
    }
}
