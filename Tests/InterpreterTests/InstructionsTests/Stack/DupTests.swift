
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionDupSpec: QuickSpec {
    override class func spec() {
        describe("Instruction DUP") {
            it("correct dup for DUP1..DUP16") {
                for n in 0 ... UInt8(15) {
                    let m = TestMachine.machine(rawCode: [Opcode.DUP1.rawValue + n], gasLimit: 10)

                    for i in (1 ... UInt64(n + 1)).reversed() {
                        let _ = m.stack.push(value: U256(from: i))
                    }

                    m.evalLoop()
                    let result = m.stack.pop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(U256(from: UInt64(n) + 1)))
                    })

                    expect(m.stack.length).to(equal(Int(n) + 1))
                    expect(m.gas.remaining).to(equal(7))
                }
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.DUP1, gasLimit: 1)

                for i in (1 ... UInt64(16)).reversed() {
                    _ = m.stack.push(value: U256(from: i))
                }

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(16))
                expect(m.gas.remaining).to(equal(1))
            }
        }

        it("check stack underflow for empty stack") {
            let m = TestMachine.machine(opcode: Opcode.DUP1, gasLimit: 10)

            m.evalLoop()
            expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            expect(m.stack.length).to(equal(0))
            expect(m.gas.remaining).to(equal(10))
        }

        it("check stack underflow for DUP1..DUP16") {
            for n in 0 ... UInt8(15) {
                let m = TestMachine.machine(rawCode: [Opcode.DUP1.rawValue + n], gasLimit: 10)
                if n > 0 {
                    for i in (1 ... UInt64(n)).reversed() {
                        let _ = m.stack.push(value: U256(from: i))
                    }
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(Int(n)))
                expect(m.gas.remaining).to(equal(10))
            }
        }

        it("check stack overflow for DUP1..DUP16") {
            for n in 0 ... UInt8(15) {
                let m = TestMachine.machine(rawCode: [Opcode.DUP1.rawValue + n], gasLimit: 10)
                for i in 1 ... UInt64(m.stack.limit) {
                    let _ = m.stack.push(value: U256(from: i))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
