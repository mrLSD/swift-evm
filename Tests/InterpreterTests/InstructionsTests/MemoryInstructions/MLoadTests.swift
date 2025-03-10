
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MLoadSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.MLOAD, gasLimit: 1)

    override class func spec() {
        describe("Instruction MLOAD") {
            it("with OutOfGas result for size=1") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }
        }

        it("check stack underflow errors is as expected") {
            var m = TestMachine.machine(opcode: Opcode.MLOAD, gasLimit: 10)
            m.evalLoop()
            expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
        }

        it("gas overflow for resized memoryGasCost") {
            var m = TestMachine.machine(opcode: Opcode.MLOAD, gasLimit: 10)
            let _ = m.stack.push(value: U256(from: 97))
            m.evalLoop()

            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
            expect(m.stack.length).to(equal(0))
            expect(m.gas.remaining).to(equal(7))
            expect(m.gas.memoryGas.numWords).to(equal(5))
            expect(m.gas.memoryGas.gasCost).to(equal(40))
        }

        it("success") {
            var m = TestMachine.machine(opcode: Opcode.MLOAD, gasLimit: 100)
            let res = m.memory.set(offset: 31, value: [UInt8](repeating: 3, count: 14), size: 14)
            expect(res).to(beSuccess())

            let _ = m.stack.push(value: U256(from: 33))
            m.evalLoop()

            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
            let resVal: [UInt8] = try! m.stack.peek(indexFromTop: 0).get().toBigEndian
            expect(Array(resVal[..<12])).to(equal([UInt8](repeating: 3, count: 12)))
            expect(Array(resVal[12..<32])).to(equal([UInt8](repeating: 0, count: 20)))

            expect(m.stack.length).to(equal(1))
            expect(m.gas.remaining).to(equal(79))
            expect(m.gas.memoryGas.numWords).to(equal(3))
            expect(m.gas.memoryGas.gasCost).to(equal(18))
        }
    }
}
