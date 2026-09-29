@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCallDataLoadSpec: QuickSpec {
    override class func spec() {
        describe("Instruction CALLDATALOAD") {
            it("loads full, partial and out-of-range words with right zero padding") {
                let data = (0 ..< 40).map { UInt8($0 + 1) }
                for offset in [0, 1, 7, 8, 9, 31, 32, 39, 40, 41, Int.max] {
                    let m = TestMachine.machine(data: data, opcode: Opcode.CALLDATALOAD, gasLimit: 10)
                    _ = m.stack.push(value: U256(from: UInt64(offset)))

                    m.evalLoop()

                    var expected = [UInt64](repeating: 0, count: 4)
                    for i in 0 ..< 32 where offset < data.count && i < data.count - offset {
                        expected[(31 - i) / 8] |= UInt64(data[offset + i]) << (((31 - i) % 8) * 8)
                    }

                    expect(m.stack.peek(indexFromTop: 0)).to(beSuccess(U256(from: expected)), description: "offset \(offset)")
                    expect(m.stack.length).to(equal(1))
                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.gas.remaining).to(equal(7))
                }
            }

            it("index = 2") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATALOAD, gasLimit: 10)
                _ = m.stack.push(value: U256(from: 2))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                var expected = [UInt8](repeating: 0, count: 32)
                expected.replaceSubrange(0 ..< 3, with: [0x03, 0x04, 0x05])
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.fromBigEndian(from: expected)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("index more than int data count") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATALOAD, gasLimit: 10)
                _ = m.stack.push(value: U256(from: 6))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("index more than int max size") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATALOAD, gasLimit: 10)
                _ = m.stack.push(value: U256(from: [UInt64.max, 1, 0, 0]))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256.ZERO))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(7))
            }

            it("with OutOfGas result") {
                let m = TestMachine.machine(data: [], opcode: Opcode.CALLDATALOAD, gasLimit: 1)
                _ = m.stack.push(value: U256(from: 5))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(1))
                expect(m.gas.remaining).to(equal(1))
            }

            it("check stack underflow") {
                let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                let m = TestMachine.machine(data: callData, opcode: Opcode.CALLDATALOAD, gasLimit: 10)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(10))
            }
        }
    }
}
