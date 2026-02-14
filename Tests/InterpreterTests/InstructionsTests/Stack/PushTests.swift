@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPushSpec: QuickSpec {
    override class func spec() {
        describe("Instruction PUSH") {
            it("PUSH n with complete code size") {
                for n in 1 ... UInt8(32) {
                    var code: [UInt8] = [Opcode.PUSH1.rawValue + n - 1]
                    let number: [UInt8] = Array(1 ... n)
                    code.append(contentsOf: number)

                    let m = TestMachine.machine(rawCode: code, gasLimit: 10)

                    m.evalLoop()
                    let result = m.stack.peek(indexFromTop: 0)

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(U256.fromBigEndian(from: number)))
                    })
                    expect(m.pc).to(equal(1 + Int(n)))
                    expect(m.stack.length).to(equal(1))
                    expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
                }
            }

            it("PUSH n with incomplete code size") {
                for n in 1 ... UInt8(32) {
                    var code: [UInt8] = [Opcode.PUSH1.rawValue + n - 1]
                    // Values only in range: 1..10
                    if n <= 10 {
                        code.append(contentsOf: Array(1 ... n))
                    } else {
                        code.append(contentsOf: Array(1 ... 10))
                    }

                    /// Generate incomplete array with zero values after index 10
                    let expectedNumber: [UInt8] = if n <= 10 {
                        Array(1 ... n)
                    } else {
                        (0 ..< n).map { index in index < 10 ? UInt8(index + 1) : 0 }
                    }

                    let m = TestMachine.machine(rawCode: code, gasLimit: 10)

                    m.evalLoop()
                    let result = m.stack.peek(indexFromTop: 0)

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(result).to(beSuccess { value in
                        expect(value).to(equal(U256.fromBigEndian(from: expectedNumber)))
                    })
                    expect(m.pc).to(equal(1 + Int(n)))
                    expect(m.stack.length).to(equal(1))
                    expect(m.gas.remaining).to(equal(10 - GasConstant.VERYLOW))
                }
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(opcode: Opcode.PUSH1, gasLimit: 1)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(1))
            }
        }

        it("check stack overflow") {
            let m = TestMachine.machine(opcode: Opcode.PUSH1, gasLimit: 10)
            for _ in 0 ..< m.stack.limit {
                _ = m.stack.push(value: U256(from: 5))
            }

            m.evalLoop()
            expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
            expect(m.stack.length).to(equal(m.stack.limit))
            expect(m.gas.remaining).to(equal(10))
        }
    }
}
