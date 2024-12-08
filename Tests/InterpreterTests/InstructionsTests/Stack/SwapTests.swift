@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSwapSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.SWAP1, gasLimit: 1)

    override class func spec() {
        describe("Instruction SWAP") {
            it("correct swap for SWAP1..SWAP16") {
                for n in 0 ... UInt8(15) {
                    var m = TestMachine.machine(rawCode: [Opcode.SWAP1.rawValue + n], gasLimit: 10)

                    for i in (1 ... UInt64(n + 2)).reversed() {
                        let _ = m.stack.push(value: U256(from: i))
                    }

                    m.evalLoop()
                    let val1 = m.stack.peek(indexFromTop: 0)
                    let val2 = m.stack.peek(indexFromTop: Int(n) + 1)

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(val1).to(beSuccess { value in
                        expect(value).to(equal(U256(from: UInt64(n) + 2)))
                    })
                    expect(val2).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 1)))
                    })

                    expect(m.stack.length).to(equal(Int(n) + 2))
                    expect(m.gas.remaining).to(equal(7))
                }
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                for i in (1 ... UInt64(16)).reversed() {
                    let _ = m.stack.push(value: U256(from: i))
                }

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(16))
                expect(m.gas.remaining).to(equal(1))
            }
        }

        it("check stack underflow for empty stack") {
            var m = TestMachine.machine(opcode: Opcode.SWAP1, gasLimit: 10)

            m.evalLoop()
            expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            expect(m.stack.length).to(equal(0))
            expect(m.gas.remaining).to(equal(10))
        }

        it("check stack underflow for SWAP1..SWAP16") {
            for n in 0 ... UInt8(15) {
                var m = TestMachine.machine(rawCode: [Opcode.SWAP1.rawValue + n], gasLimit: 10)
                for i in (1 ... UInt64(n + 1)).reversed() {
                    let _ = m.stack.push(value: U256(from: i))
                }

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(Int(n) + 1))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
