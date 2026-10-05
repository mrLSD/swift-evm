@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ClzSpec: QuickSpec {
    override class func spec() {
        describe("Instruction CLZ") {
            it("activates at Osaka and checks the fork before stack or gas") {
                for fork in HardFork.allCases {
                    for count in [0, 1] {
                        let m = TestMachine.machine(opcode: .CLZ, gasLimit: 0, context: TestMachine.defaultContext(), hardFork: fork)
                        if count == 1 { m.stackPush(value: .MAX) }
                        m.evalLoop()
                        let error: Machine.ExitError = fork.rawValue < HardFork.Osaka.rawValue ? .HardForkNotActive : count == 0 ? .StackUnderflow : .OutOfGas
                        expect(m.machineStatus).to(equal(.Exit(.Error(error))), description: "fork=\(fork), count=\(count)")
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.stack.length).to(equal(count))
                    }
                }
            }

            it("counts every leading-bit position and charges exactly five gas") {
                for bit in 0 ... 256 {
                    let value: U256 = bit == 256 ? .ZERO : U256(from: 1) << bit
                    let expected = U256(from: UInt64(bit == 256 ? 256 : 255 - bit))
                    let m = TestMachine.machine(opcode: .CLZ, gasLimit: 5, context: TestMachine.defaultContext(), hardFork: .Osaka)
                    m.stackPush(value: value)
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([expected]), description: "bit=\(bit)")
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.pc).to(equal(1))
                }
            }

            it("replaces the top item on a full stack and rejects insufficient gas without consuming it") {
                for gas: UInt64 in [4, 5] {
                    let m = TestMachine.machine(opcode: .CLZ, gasLimit: gas, context: TestMachine.defaultContext(), hardFork: .Osaka)
                    for _ in 0 ..< 1024 { m.stackPush(value: .MAX) }
                    m.evalLoop()
                    expect(m.stack.length).to(equal(1024))
                    if gas == 4 {
                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.stack.data.last).to(equal(.MAX))
                        expect(m.gas.remaining).to(equal(4))
                    } else {
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data.last).to(equal(.ZERO))
                        expect(m.stack.data.dropLast().allSatisfy { $0 == .MAX }).to(beTrue())
                        expect(m.gas.remaining).to(equal(0))
                    }
                }
            }
        }
    }
}
