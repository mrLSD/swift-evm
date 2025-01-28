

@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionJumpiSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.JUMPI, gasLimit: 1)

    override class func spec() {
        describe("Instruction JUMPI") {
            it("Correct JUMPI") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.PUSH1.rawValue, 0x6, Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.pc).to(equal(7))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(3))
            }

            it("zero value") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x0, Opcode.PUSH1.rawValue, 0x6, Opcode.JUMPI.rawValue, Opcode.JUMPDEST.rawValue, Opcode.JUMPDEST.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 21)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.pc).to(equal(8))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("Invalid JUMPI to PUSH1 range") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.PUSH1.rawValue, 0x3, Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidJump))))
                expect(m.pc).to(equal(4))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
            }

            it("Invalid JUMP to non JUMPDEST opcode") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.PUSH1.rawValue, 0x4, Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidJump))))
                expect(m.pc).to(equal(4))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
            }

            it("JUMPDEST too large") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.PUSH8.rawValue, 0x80, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(m.pc).to(equal(11))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("with OutOfGas result for JUMPDEST") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1, Opcode.PUSH1.rawValue, 0x6, Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 16)

                m.evalLoop()

                m.evalLoop()

                expect(m.pc).to(equal(6))
                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
            }

            it("check stack underflow for partly empty stack") {
                var m = TestMachine.machine(opcode: Opcode.JUMPI, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
            }

            it("check stack underflow for empty stack - empty target") {
                var m = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0x1,  Opcode.JUMPI.rawValue, Opcode.PC.rawValue, Opcode.JUMPDEST.rawValue], gasLimit: 20)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }
        }
    }
}
