@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionBaseFeeSpec: QuickSpec {
    override class func spec() {
        describe("Instruction BASEFEE") {
            it("returns the block base fee at the exact gas budget from London onward") {
                let values: [U256] = [
                    .ZERO, U256(from: 1), U256(from: 7), U256(from: 10_000_000_000),
                    U256(from: UInt64.max),
                    U256(l0: 0, l1: 1, h0: 0, h1: 0),
                    U256(l0: 0, l1: 0, h0: 1, h1: 0),
                    U256(l0: 0, l1: 0, h0: 0, h1: 1), .MAX
                ]
                let forks = HardFork.allCases.drop(while: { $0 != .London })
                expect(forks.first).to(equal(.London))
                for fork in forks {
                    for value in values {
                        let m = TestMachine.machine(opcodes: [.BASEFEE], gasLimit: 2, memoryLimit: 0, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.blockBaseFeePerGasValue = value
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        let detail = "fork \(fork), block base fee \(value)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), value]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(handler.blockBaseFeePerGasRequests).to(equal(1), description: detail)
                    }
                }
            }

            it("rejects every pre-London fork before checking the stack, gas or handler") {
                let forks = HardFork.allCases.prefix(while: { $0 != .London })
                expect(forks.last).to(equal(.Berlin))
                for fork in forks {
                    for budget: UInt64 in [0, 1, 2, 10] {
                        for fullStack in [false, true] {
                            let m = TestMachine.machine(opcodes: [.BASEFEE], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                            if fullStack {
                                for _ in 0 ..< m.stack.limit {
                                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                                }
                            }
                            let original = m.stack.data
                            let detail = "fork \(fork), gas budget \(budget), full stack \(fullStack)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: detail)
                            expect(m.stack.data).to(equal(original), description: detail)
                            expect(m.gas.remaining).to(equal(budget), description: detail)
                            expect(m.pc).to(equal(0), description: detail)
                            expect((m.handler as! TestHandler).blockBaseFeePerGasRequests).to(equal(0), description: detail)
                        }
                    }
                }
            }

            it("executes the EIP-3198 example on London") {
                let m = TestMachine.machine(opcodes: [.BASEFEE, .STOP], gasLimit: 2, memoryLimit: 0, hardFork: .London)
                let handler = m.handler as! TestHandler
                handler.blockBaseFeePerGasValue = U256(from: 7)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 7)]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.pc).to(equal(1))
                expect(handler.blockBaseFeePerGasRequests).to(equal(1))
            }

            it("preserves the stack and does not query the handler when gas is insufficient") {
                for budget: UInt64 in [0, 1] {
                    let m = TestMachine.machine(opcode: .BASEFEE, gasLimit: budget)
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                    let detail = "gas budget \(budget)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                    expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                    expect(m.gas.remaining).to(equal(budget), description: detail)
                    expect(m.pc).to(equal(0), description: detail)
                    expect((m.handler as! TestHandler).blockBaseFeePerGasRequests).to(equal(0), description: detail)
                }
            }

            it("rejects stack overflow before charging gas or querying the handler") {
                for budget: UInt64 in [0, 1, 2, 10] {
                    let m = TestMachine.machine(opcode: .BASEFEE, gasLimit: budget)
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
                    expect((m.handler as! TestHandler).blockBaseFeePerGasRequests).to(equal(0), description: detail)
                }
            }

            it("fills the last stack slot without changing existing values") {
                let m = TestMachine.machine(opcode: .BASEFEE, gasLimit: 10)
                for i in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                }
                let original = m.stack.data
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(original + [handler.blockBaseFeePerGasValue]))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(8))
                expect(m.pc).to(equal(1))
                expect(handler.blockBaseFeePerGasRequests).to(equal(1))
            }

            it("returns the block base fee independently of the transaction gas price and remaining gas") {
                let m = TestMachine.machine(opcodes: [.BASEFEE, .GASPRICE, .GAS, .BASEFEE], gasLimit: 10)
                let handler = m.handler as! TestHandler
                handler.blockBaseFeePerGasValue = U256(from: 40_000_000)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 40_000_000), U256(from: 123), U256(from: 4), U256(from: 40_000_000)]))
                expect(m.gas.remaining).to(equal(2))
                expect(m.pc).to(equal(4))
                expect(handler.blockBaseFeePerGasRequests).to(equal(2))
            }

            it("stops before querying the handler when a subsequent instruction runs out of gas") {
                let m = TestMachine.machine(opcodes: [.BASEFEE, .BASEFEE, .POP], gasLimit: 3)
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.data).to(equal([handler.blockBaseFeePerGasValue]))
                expect(m.gas.remaining).to(equal(1))
                expect(m.pc).to(equal(1))
                expect(handler.blockBaseFeePerGasRequests).to(equal(1))
            }

            it("preserves memory and gas refunds") {
                let m = TestMachine.machine(opcode: .BASEFEE, gasLimit: 10)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                m.gas.recordRefund(refund: 5)
                let memory = m.memory.get(offset: 0, size: 32)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 7)]))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.gas.memoryGas.numWords).to(equal(1))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.gas.refunded).to(equal(5))
                expect(m.gas.remaining).to(equal(5))
            }

            it("is allowed in a static call") {
                let handler = StaticHandler()
                handler.blockBaseFeePerGasValue = U256(from: 60_000_000)
                let m = Machine(data: [], code: [Opcode.BASEFEE.rawValue], gasLimit: 2, memoryLimit: 0,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .London)
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 60_000_000)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockBaseFeePerGasRequests).to(equal(1))
                expect(handler.logs).to(beEmpty())
            }

            #if TRACING
            it("traces the pushed block base fee and instruction cost") {
                let m = TestMachine.machine(opcode: .BASEFEE, gasLimit: 10)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.BASEFEE))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), U256(from: 7)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(8))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(beEmpty())
                expect(m.trace.data.first?.stackIn).to(equal([U256(from: 7)]))
                #endif
            }
            #endif
        }
    }
}
