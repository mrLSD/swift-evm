@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionNotSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.NOT, gasLimit: 10)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.NOT, gasLimit: 2)

    override class func spec() {
        describe("Instruction NOT") {
            it("~a") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: [1, 2, 3, 4]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [UInt64.max - 1, UInt64.max - 2, UInt64.max - 3, UInt64.max - 4])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }

            it("check stack") {
                var m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m1 = Self.machine
                let _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
