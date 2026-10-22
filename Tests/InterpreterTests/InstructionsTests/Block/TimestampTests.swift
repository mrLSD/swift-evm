@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionTimestampSpec: QuickSpec {
    override class func spec() {
        describe("Instruction TIMESTAMP") {
            it("returns the block timestamp in seconds at the exact gas budget on every hard fork") {
                let values: [U256] = [
                    .ZERO, U256(from: 1), U256(from: 1_700_000_123),
                    U256(from: 0x8000_0000), U256(from: 0x1_0000_0000), U256(from: UInt64.max),
                    U256(l0: 0, l1: 1, h0: 0, h1: 0),
                    U256(l0: 0, l1: 0, h0: 1, h1: 0),
                    U256(l0: 0, l1: 0, h0: 0, h1: 1), .MAX
                ]
                for fork in HardFork.allCases {
                    for value in values {
                        let m = TestMachine.machine(opcodes: [.TIMESTAMP], gasLimit: 2, memoryLimit: 0, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.blockTimestampValue = value
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        let detail = "fork \(fork), block timestamp in seconds \(value)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), value]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(handler.blockTimestampRequests).to(equal(1), description: detail)
                    }
                }
            }

            it("preserves the stack and does not query the handler when gas is insufficient") {
                for budget: UInt64 in [0, 1] {
                    let m = TestMachine.machine(opcode: .TIMESTAMP, gasLimit: budget)
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                    let detail = "gas budget \(budget)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                    expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                    expect(m.gas.remaining).to(equal(budget), description: detail)
                    expect(m.pc).to(equal(0), description: detail)
                    expect((m.handler as! TestHandler).blockTimestampRequests).to(equal(0), description: detail)
                }
            }

            it("rejects stack overflow before charging gas or querying the handler") {
                for budget: UInt64 in [0, 1, 2, 10] {
                    let m = TestMachine.machine(opcode: .TIMESTAMP, gasLimit: budget)
                    for i in 0 ..< m.stack.limit {
                        expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                    }
                    let original = m.stack.data
                    let detail = "gas budget \(budget)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))), description: detail)
                    expect(m.stack.data).to(equal(original), description: detail)
                    expect(m.gas.remaining).to(equal(budget), description: detail)
                    expect(m.pc).to(equal(0), description: detail)
                    expect((m.handler as! TestHandler).blockTimestampRequests).to(equal(0), description: detail)
                }
            }

            it("fills the last stack slot without changing existing values") {
                let m = TestMachine.machine(opcode: .TIMESTAMP, gasLimit: 10)
                for i in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                }
                let original = m.stack.data
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(original + [handler.blockTimestampValue]))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
                expect(m.pc).to(equal(1))
                expect(handler.blockTimestampRequests).to(equal(1))
            }

            it("returns the block timestamp independently of the changing execution gas") {
                let m = TestMachine.machine(opcodes: [.TIMESTAMP, .GAS, .TIMESTAMP], gasLimit: 10)
                let handler = m.handler as! TestHandler
                handler.blockTimestampValue = U256(from: 1_800_000_456)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 1_800_000_456), U256(from: 6), U256(from: 1_800_000_456)]))
                expect(m.gas.remaining).to(equal(4))
                expect(m.pc).to(equal(3))
                expect(handler.blockTimestampRequests).to(equal(2))
            }

            it("stops before querying the handler when a subsequent instruction runs out of gas") {
                let m = TestMachine.machine(opcodes: [.TIMESTAMP, .TIMESTAMP, .POP], gasLimit: 3)
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.data).to(equal([handler.blockTimestampValue]))
                expect(m.gas.remaining).to(equal(1))
                expect(m.pc).to(equal(1))
                expect(handler.blockTimestampRequests).to(equal(1))
            }

            it("preserves memory and gas refunds") {
                let m = TestMachine.machine(opcode: .TIMESTAMP, gasLimit: 10)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                m.gas.recordRefund(refund: 5)
                let memory = m.memory.get(offset: 0, size: 32)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 1_700_000_123)]))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.gas.memoryGas.numWords).to(equal(1))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.gas.refunded).to(equal(5))
                expect(m.gas.remaining).to(equal(5))
            }

            it("is allowed in a static call") {
                let handler = StaticHandler()
                handler.blockTimestampValue = U256(from: 1_900_000_789)
                let m = Machine(data: [], code: [Opcode.TIMESTAMP.rawValue], gasLimit: 2, memoryLimit: 0,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Byzantium)
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 1_900_000_789)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockTimestampRequests).to(equal(1))
                expect(handler.logs).to(beEmpty())
            }

            #if TRACING
            it("traces the pushed block timestamp in seconds and instruction cost") {
                let m = TestMachine.machine(opcode: .TIMESTAMP, gasLimit: 10)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.TIMESTAMP))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), U256(from: 1_700_000_123)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(8))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(beEmpty())
                expect(m.trace.data.first?.stackIn).to(equal([U256(from: 1_700_000_123)]))
                #endif
            }
            #endif
        }
    }
}
