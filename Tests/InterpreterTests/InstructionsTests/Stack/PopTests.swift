@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPopSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.POP, gasLimit: 1)

    override class func spec() {
        describe("Instruction POP") {
            it("POP 1") {
                var m = TestMachine.machine(opcode: Opcode.POP, gasLimit: 10)

                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("POP 4") {
                var m = TestMachine.machine(opcodes: [Opcode.POP, Opcode.POP, Opcode.POP, Opcode.POP], gasLimit: 10)
                for _ in 0 ..< 10 {
                    let _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(6))
                expect(m.gas.remaining).to(equal(2))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                var m = TestMachine.machine(opcode: Opcode.POP, gasLimit: 10)
                expect(m.stack.length).to(equal(0))

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }
        }
    }
}
