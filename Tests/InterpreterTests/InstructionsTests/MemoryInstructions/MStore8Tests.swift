
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MStore8Spec: QuickSpec {
    override class func spec() {
        describe("Instruction MSTORE8") {
            it("writes only the low byte at the last byte of an allocated word") {
                let cases: [(value: U256, byte: UInt8)] = [
                    (.ZERO, 0), (.MAX, 255), (U256(from: 255), 255), (U256(from: 256), 0),
                    (U256(from: [0xAB, .max, .max, .max]), 0xAB),
                ]
                for testCase in cases {
                    let m = TestMachine.machine(opcodes: [.MSTORE8], gasLimit: 6, memoryLimit: 32)
                    expect(m.memory.set(offset: 0, value: [UInt8](repeating: 0xEE, count: 32), size: 32)).to(beSuccess())
                    m.stackPush(value: testCase.value)
                    m.stackPush(value: U256(from: 31))
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 0xEE, count: 31) + [testCase.byte]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.stack.length).to(equal(0))
                }
            }

            it("with OutOfGas result for index=0") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 1)
                _ = m.stack.push(value: U256(from: 0))
                _ = m.stack.push(value: U256(from: 0))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(1))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("check stack underflow errors is as expected") {
                let m1 = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m1.gas.remaining).to(equal(10))
                expect(m1.gas.memoryGas.numWords).to(equal(0))
                expect(m1.gas.memoryGas.gasCost).to(equal(0))

                let m2 = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                _ = m2.stack.push(value: U256(from: 0))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m2.gas.remaining).to(equal(10))
                expect(m2.gas.memoryGas.numWords).to(equal(0))
                expect(m2.gas.memoryGas.gasCost).to(equal(0))
            }

            it("gas overflow for resized memoryGasCost") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 10)
                // Value
                _ = m.stack.push(value: U256(from: 1))
                // Index
                _ = m.stack.push(value: U256(from: 97))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(12))
            }

            it("fails with OutOfGas before allocating beyond the memory limit") {
                let m = TestMachine.machine(opcodes: [Opcode.MSTORE8], gasLimit: 100, memoryLimit: 100)

                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: 100))
                m.evalLoop()

                expect(m.machineStatus)
                    .to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.memory.effectiveLength).to(equal(0))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(85))
                expect(m.gas.memoryGas.numWords).to(equal(4))
                expect(m.gas.memoryGas.gasCost).to(equal(12))
            }

            it("check stack Int failure is as expected") {
                let m = TestMachine.machine(opcodes: [Opcode.MSTORE8], gasLimit: 100, memoryLimit: 100)
                _ = m.stack.push(value: U256(from: 1))
                _ = m.stack.push(value: U256(from: [1, 1, 0, 0]))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(97))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }

            it("success") {
                let m = TestMachine.machine(opcode: Opcode.MSTORE8, gasLimit: 100)

                _ = m.stack.push(value: U256(from: 3))
                _ = m.stack.push(value: U256(from: 33))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let resVal: [UInt8] = m.memory.get(offset: 32, size: 3)

                expect(resVal).to(equal([0, 3, 0]))

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(91))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
            }
        }
    }
}
