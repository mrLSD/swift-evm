@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCallDataSizeSpec: QuickSpec {
    override class func spec() {
        describe("Instruction CALLDATASIZE") {
            it("data size = 0") {
                let m = TestMachine.machine(data: [], opcode: Opcode.CALLDATASIZE, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("data size = 5") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATASIZE, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.CALLDATASIZE, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack overflow") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATASIZE, gasLimit: 10)
                for _ in 0 ..< m.stack.limit {
                    _ = m.stack.push(value: U256(from: 5))
                }

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
            }
        }
    }
}
