@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExpSpec: QuickSpec {
    @MainActor
    static let machine = TestMachine.machine(opcode: Opcode.EXP, gasLimit: 75)
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.EXP, gasLimit: 2)

    override class func spec() {
        describe("Instruction Exp") {
            it("2 exp 6") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 8)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(15))
            }

            it("2 exp 6 for Tangerine hard fork") {
                var m = TestMachine.machine(opcodes: [Opcode.EXP], gasLimit: 75, memoryLimit: 1024, HardFork: HardFork.Tangerine)

                let _ = m.stack.push(value: U256(from: 3))
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 8)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(55))
            }

            it("2 exp MAX") {
                var m = Self.machine

                let _ = m.stack.push(value: U256.MAX)
                let _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(75))
            }

            it("`a exp b`, when `b` not in the stack") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 1))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(75))
            }

            it("(a exp 0)") {
                var m = Self.machine

                let _ = m.stack.push(value: U256(from: 0))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()
                let result = m.stack.pop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 1)))
                })
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(65))
            }

            it("Add with OutOfGas result") {
                var m = Self.machineLowGas

                let _ = m.stack.push(value: U256(from: 1))
                let _ = m.stack.push(value: U256(from: 2))
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(2))
            }
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

        context("log2floor logic") {
            it("log2floor [0,0,0,0]") {
                let u256Value = U256(from: [0, 0, 0, 0])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 0

                expect(result).to(equal(expected))
            }

            it("log2floor [2,0,0,0]") {
                let u256Value = U256(from: [2, 0, 0, 0])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 1

                expect(result).to(equal(expected))
            }

            it("log2floor [1,0,0,0]") {
                let u256Value = U256(from: [1, 0, 0, 0])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 0

                expect(result).to(equal(expected))
            }

            it("log2floor [0,1,0,0]") {
                let u256Value = U256(from: [0, 1, 0, 0])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 64

                expect(result).to(equal(expected))
            }

            it("log2floor [0,0,1,0]") {
                let u256Value = U256(from: [0, 0, 1, 0])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 128

                expect(result).to(equal(expected))
            }

            it("log2floor [0,0,0,1]") {
                let u256Value = U256(from: [0, 0, 0, 1])
                let result = GasCost.log2floor(u256Value)
                let expected: UInt64 = 192

                expect(result).to(equal(expected))
            }
        }
    }
}
