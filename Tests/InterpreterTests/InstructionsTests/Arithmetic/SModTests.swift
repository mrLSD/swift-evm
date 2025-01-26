@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSModSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.SMOD, gasLimit: 10)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.SMOD, gasLimit: 2)

    override class func spec() {
        describe("Instruction SMod") {
            it("5 % 2") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("-5 % 2") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 2))
                let _ = m.stack.push(value: I256(from: [5, 0, 0, 0], signExtend: true).toU256)
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(I256(from: [1, 0, 0, 0], signExtend: true).toU256))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("-5 % 0") {
                var m = Self.machine

                let _ = m.stack.push(value: U256.ZERO)
                let _ = m.stack.push(value: I256(from: [5, 0, 0, 0], signExtend: true).toU256)
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("`a % b`, when `b` not in the stack") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(5))
            }

            it("max values 1") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: [UInt64.max-1, UInt64.max-1, UInt64.max-1, UInt64.max-1]))
                let _ = m.stack.push(value: U256(from: [UInt64.max-1, 0, 0, 0]))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: [18446744073709551614, 0, 0, 0])))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("by zero") {
                var m = Self.machine

                let _ = m.stack.push(value: U256.ZERO)
                let _ = m.stack.push(value: U256(from: 5))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(GasConstant.LOW))
            }

            it("with OutOfGas result") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 5))
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
