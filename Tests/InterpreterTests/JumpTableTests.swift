@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class JumpTableSpec: QuickSpec {
    override class func spec() {
        describe("Machine JumpTable") {
            it("check opcodes index and out of code size") {
                let m = TestMachine.machine(opcodes: [Opcode.ADD, Opcode.PC, Opcode.SUB], gasLimit: 10)
                for i in 0 ..< m.codeSize + 5 {
                    let isValue = m.isValidJumpDestination(at: i)
                    expect(isValue).to(equal(false))
                }
            }

            it("check in PUSH range") {
                let m = TestMachine.machine(rawCode: [Opcode.ADD.rawValue, Opcode.JUMPDEST.rawValue, Opcode.PUSH2.rawValue, Opcode.JUMPDEST.rawValue, Opcode.JUMPDEST.rawValue, Opcode.JUMPDEST.rawValue, Opcode.ADD.rawValue], gasLimit: 20)

                expect(m.isValidJumpDestination(at: 0)).to(equal(false))
                expect(m.isValidJumpDestination(at: 1)).to(equal(true))
                expect(m.isValidJumpDestination(at: 2)).to(equal(false))
                expect(m.isValidJumpDestination(at: 3)).to(equal(false))
                expect(m.isValidJumpDestination(at: 4)).to(equal(false))
                expect(m.isValidJumpDestination(at: 5)).to(equal(true))
                expect(m.isValidJumpDestination(at: 6)).to(equal(false))
            }
        }
    }
}
