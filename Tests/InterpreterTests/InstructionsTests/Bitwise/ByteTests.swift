@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionByteSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.BYTE, gasLimit: 10)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.BYTE, gasLimit: 2)

    override class func spec() {
        describe("Instruction BYTE") {
            it("BYTE(a, 0)") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 6))
                let _ = m.stack.push(value: U256(from: 0))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("BYTE(a, b) for 32 bits") {
                for i in 0 ..< 31 {
                    var m = Self.machine
                    let inputValue = U256(from: [0x123456789ABCDEF, 0x123456789ABCDEF, 0, 0])
                    let shiftAmount = (31 - i) * 8
                    let expectedValue = (inputValue >> shiftAmount) & U256(from: 0xFF)

                    let _ = m.stack.push(value: inputValue)
                    let _ = m.stack.push(value: U256(from: UInt64(i)))
                    m.evalLoop()
                    let result = m.stack.pop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(expectedValue))
                    })
                    expect(m.stack.length).to(equal(0))
                    expect(m.gas.remaining).to(equal(7))
                }
            }

            it("`BYTE(a, b)`, when `b` not in the stack") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(2))
                expect(m.gas.remaining).to(equal(2))
            }

            it("check stack") {
                var m = Self.machine
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m1 = Self.machine
                let _ = m1.stack.push(value: U256(from: 5))
                m1.evalLoop()
                expect(m1.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))

                var m2 = Self.machine
                let _ = m2.stack.push(value: U256(from: 2))
                let _ = m2.stack.push(value: U256(from: 2))
                m2.evalLoop()
                expect(m2.machineStatus).to(equal(.Exit(.Success(.Stop))))
            }
        }
    }
}
