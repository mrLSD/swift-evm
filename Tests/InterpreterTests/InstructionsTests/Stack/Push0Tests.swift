@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPush0Spec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 1)

    override class func spec() {
        describe("Instruction PUSH0") {
            it("PUSH 0") {
                var m = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 10)

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                var m = TestMachine.machine(opcode: Opcode.PUSH0, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    let _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
            }
        }
    }
}

