@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MSizeSpec: QuickSpec {
    override class func spec() {
        describe("Instruction MSIZE") {
            it("with OutOfGas result for index=0") {
                let m = TestMachine.machine(opcode: Opcode.MSIZE, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("success") {
                let m = TestMachine.machine(opcode: Opcode.MSIZE, gasLimit: 10)
                let res = m.memory.set(offset: 31, value: [UInt8](repeating: 3, count: 14), size: 14)
                expect(res).to(beSuccess())
                expect(m.memory.effectiveLength).to(equal(64))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let resVal = try! m.stack.peek(indexFromTop: 0).get()
                expect(resVal).to(equal(U256(from: 64)))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(8))
            }

            it("check stack overflow") {
                let m = TestMachine.machine(opcode: Opcode.MSIZE, gasLimit: 10)
                let res = m.memory.set(offset: 31, value: [UInt8](repeating: 3, count: 14), size: 14)
                expect(res).to(beSuccess())
                expect(m.memory.effectiveLength).to(equal(64))

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
