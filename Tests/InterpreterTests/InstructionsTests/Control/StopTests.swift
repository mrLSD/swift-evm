@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionStopSpec: QuickSpec {
    override class func spec() {
        describe("Instruction STOP") {
            it("Stop immediately") {
                 let m = TestMachine.machine(opcodes: [Opcode.STOP, Opcode.PC], gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.pc).to(equal(0))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }

            it("Stop after multiple instructions") {
                 let m = TestMachine.machine(opcodes: [Opcode.PC, Opcode.PC, Opcode.PC, Opcode.STOP], gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                for i in (0 ..< 3).reversed() {
                    let result = m.stack.pop()
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(U256(from: UInt64(i))))
                    })
                }
                expect(m.pc).to(equal(3))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(4))
            }
        }
    }
}
