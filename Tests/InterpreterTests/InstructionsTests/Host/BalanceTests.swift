@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

class InstructionBalanceSpec: QuickSpec {
    override class func spec() {
        describe("Instruction BALANCE") {
            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.BALANCE, gasLimit: 1)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m.stack.push(value: val1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack") {
                let m = TestMachine.machine(opcode: Opcode.BALANCE, gasLimit: 3000)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                let m1 = TestMachine.machine(opcode: Opcode.BALANCE, gasLimit: 3000)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m1.stack.push(value: val1)

                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }

            it("get not existed address") {
                let m = TestMachine.machine(opcode: Opcode.BALANCE, gasLimit: 3000)
                _ = m.stack.push(value: U256(from: 1))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(400))
            }

            it("cold and warm address") {
                let m = TestMachine.machine(opcodes: [Opcode.BALANCE, Opcode.POP, Opcode.BALANCE], gasLimit: 3000)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m.stack.push(value: val1)
                _ = m.stack.push(value: val1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })

                expect(m.stack.length).to(equal(0))
                // Gas cost = 2600 (cold) + 100 (warm) + 2 (POP opcode)
                expect(m.gas.remaining).to(equal(298))
            }

            it("Istanbul hard fork") {
                let m = TestMachine.machine(opcodes: [Opcode.BALANCE], gasLimit: 3000, memoryLimit: 1024, hardFork: .Istanbul)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m.stack.push(value: val1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2300))
            }

            it("Tangerine hard fork") {
                let m = TestMachine.machine(opcodes: [Opcode.BALANCE], gasLimit: 3000, memoryLimit: 1024, hardFork: .Tangerine)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m.stack.push(value: val1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2600))
            }

            it("Homestead hard fork") {
                let m = TestMachine.machine(opcodes: [Opcode.BALANCE], gasLimit: 3000, memoryLimit: 1024, hardFork: .Homestead)
                let val1 = U256.fromBigEndian(from: H256(from: TestHandler.address1).BYTES)
                _ = m.stack.push(value: val1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 5)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2980))
            }
        }
    }
}
