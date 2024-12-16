@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPcSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.PC, gasLimit: 1)

    override class func spec() {
        describe("Instruction PC") {
            it("PC = 1") {
                var m = TestMachine.machine(opcode: Opcode.PC, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.pc).to(equal(1))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("PC = 4") {
                var m = TestMachine.machine(opcodes: [Opcode.PC, Opcode.PC, Opcode.PC, Opcode.PC], gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                for i in (0 ..< 4).reversed() {
                    let result = m.stack.pop()
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(U256(from: UInt64(i))))
                    })
                }

                expect(m.pc).to(equal(4))
                expect(m.stack.length).to(equal(0))
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
                var m = TestMachine.machine(opcode: Opcode.PC, gasLimit: 10)
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
