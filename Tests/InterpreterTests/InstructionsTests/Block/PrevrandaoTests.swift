@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionPrevrandaoSpec: QuickSpec {
    override class func spec() {
        describe("Instruction DIFFICULTY / PREVRANDAO") {
            let values: [U256] = [
                .ZERO, U256(from: 1), U256(from: UInt64.max),
                U256(l0: 0, l1: 1, h0: 0, h1: 0),
                U256(l0: 0, l1: 0, h0: 1, h1: 0),
                U256(l0: 0, l1: 0, h0: 0, h1: 1), .MAX
            ]

            it("returns difficulty from Frontier through London even when randomness is supplied") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Paris })
                expect(forks.isEmpty).to(beFalse())

                for fork in forks {
                    for value in values {
                        for randomness: H256? in [nil, .MAX] {
                            let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 2, memoryLimit: 0, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.blockDifficultyValue = value
                            handler.blockRandomnessValue = randomness
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            let detail = "fork \(fork), difficulty \(value), randomness \(String(describing: randomness))"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 99), value]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(m.memory.effectiveLength).to(equal(0), description: detail)
                            expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                            expect(m.pc).to(equal(1), description: detail)
                            expect(handler.blockDifficultyRequests).to(equal(1), description: detail)
                            expect(handler.blockRandomnessRequests).to(equal(0), description: detail)
                        }
                    }
                }
            }

            it("returns randomness from Paris onward including zero and values below the PoS heuristic threshold") {
                let forks = HardFork.allCases.drop(while: { $0 != .Paris })
                expect(forks.isEmpty).to(beFalse())

                for fork in forks {
                    for value in values {
                        let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 2, memoryLimit: 0, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.blockDifficultyValue = U256(from: 999)
                        handler.blockRandomnessValue = H256(from: value)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        let detail = "fork \(fork), randomness \(value)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), value]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(handler.blockDifficultyRequests).to(equal(0), description: detail)
                        expect(handler.blockRandomnessRequests).to(equal(1), description: detail)
                    }
                }
            }

            it("interprets all randomness bytes as a big-endian EVM word") {
                let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 2, memoryLimit: 32, hardFork: .Paris)
                let handler = m.handler as! TestHandler
                handler.blockRandomnessValue = H256(from: (0 ..< 32).map { UInt8($0) })

                m.evalLoop()

                let expected = U256(l0: 0x1819_1a1b_1c1d_1e1f, l1: 0x1011_1213_1415_1617,
                                    h0: 0x0809_0a0b_0c0d_0e0f, h1: 0x0001_0203_0405_0607)
                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([expected]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockDifficultyRequests).to(equal(0))
                expect(handler.blockRandomnessRequests).to(equal(1))
            }

            it("requires randomness from Paris instead of falling back to difficulty") {
                let forks = HardFork.allCases.drop(while: { $0 != .Paris })
                expect(forks.isEmpty).to(beFalse())

                for fork in forks {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 2, memoryLimit: 32, hardFork: fork)
                    let handler = m.handler as! TestHandler
                    handler.blockRandomnessValue = nil

                    expect(captureStandardError {
                        expect { m.evalLoop() }.to(throwAssertion())
                    }).to(contain("PREVRANDAO requires block randomness from Paris"), description: "fork \(fork)")
                    expect(handler.blockDifficultyRequests).to(equal(0))
                    expect(handler.blockRandomnessRequests).to(equal(1))
                }
            }

            it("preserves the stack and does not query the handler when gas is insufficient") {
                for fork in [HardFork.London, .Paris] {
                    for budget: UInt64 in [0, 1] {
                        let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: budget, memoryLimit: 32, hardFork: fork)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        let detail = "fork \(fork), gas budget \(budget)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                        expect(m.gas.remaining).to(equal(budget), description: detail)
                        expect(m.pc).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blockDifficultyRequests).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blockRandomnessRequests).to(equal(0), description: detail)
                    }
                }
            }

            it("rejects stack overflow before charging gas or querying the handler") {
                for fork in [HardFork.London, .Paris] {
                    for budget: UInt64 in [0, 1, 2, 10] {
                        let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: budget, memoryLimit: 32, hardFork: fork)
                        for i in 0 ..< m.stack.limit {
                            expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                        }
                        let original = m.stack.data
                        let detail = "fork \(fork), gas budget \(budget)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))), description: detail)
                        expect(m.stack.data).to(equal(original), description: detail)
                        expect(m.gas.remaining).to(equal(budget), description: detail)
                        expect(m.pc).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blockDifficultyRequests).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blockRandomnessRequests).to(equal(0), description: detail)
                    }
                }
            }

            it("fills the last stack slot without changing existing values") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    for i in 0 ..< m.stack.limit - 1 {
                        expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                    }
                    let original = m.stack.data
                    let handler = m.handler as! TestHandler

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal(original + [expected]))
                    expect(m.stack.length).to(equal(m.stack.limit))
                    expect(m.gas.remaining).to(equal(8))
                    expect(m.pc).to(equal(1))
                    expect(handler.blockDifficultyRequests).to(equal(fork == .London ? 1 : 0))
                    expect(handler.blockRandomnessRequests).to(equal(fork == .Paris ? 1 : 0))
                }
            }

            it("returns the difficulty or PREVRANDAO independently of the changing execution gas") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO, .GAS, .PREVRANDAO], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    let handler = m.handler as! TestHandler

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([expected, U256(from: 6), expected]))
                    expect(m.gas.remaining).to(equal(4))
                    expect(m.pc).to(equal(3))
                    expect(handler.blockDifficultyRequests).to(equal(fork == .London ? 2 : 0))
                    expect(handler.blockRandomnessRequests).to(equal(fork == .Paris ? 2 : 0))
                }
            }

            it("stops before querying the handler when a subsequent instruction runs out of gas") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO, .PREVRANDAO, .POP], gasLimit: 3, memoryLimit: 32, hardFork: fork)
                    let handler = m.handler as! TestHandler

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal([expected]))
                    expect(m.gas.remaining).to(equal(1))
                    expect(m.pc).to(equal(1))
                    expect(handler.blockDifficultyRequests).to(equal(fork == .London ? 1 : 0))
                    expect(handler.blockRandomnessRequests).to(equal(fork == .Paris ? 1 : 0))
                }
            }

            it("preserves memory and gas refunds") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                    expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                    m.gas.recordRefund(refund: 5)
                    let memory = m.memory.get(offset: 0, size: 32)

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([expected]))
                    expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                    expect(m.memory.effectiveLength).to(equal(32))
                    expect(m.gas.memoryGas.numWords).to(equal(1))
                    expect(m.gas.memoryGas.gasCost).to(equal(3))
                    expect(m.gas.refunded).to(equal(5))
                    expect(m.gas.remaining).to(equal(5))
                }
            }

            it("is allowed in a static call") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let handler = StaticHandler()
                    let m = Machine(data: [], code: [Opcode.PREVRANDAO.rawValue], gasLimit: 2, memoryLimit: 0,
                                    context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: fork)
                    expect(handler.isStatic()).to(beTrue())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([expected]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.blockDifficultyRequests).to(equal(fork == .London ? 1 : 0))
                    expect(handler.blockRandomnessRequests).to(equal(fork == .Paris ? 1 : 0))
                    expect(handler.logs).to(beEmpty())
                }
            }

            #if TRACING
            it("traces the pushed difficulty or PREVRANDAO and instruction cost") {
                for (fork, expected) in [(HardFork.London, U256(from: 999)), (.Paris, U256(from: 22))] {
                    let m = TestMachine.machine(opcodes: [.PREVRANDAO], gasLimit: 10, memoryLimit: 32, hardFork: fork)
                    m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99)]))
                    expect(m.trace.data.count).to(equal(1))
                    expect(m.trace.data.first?.opcode).to(equal(.PREVRANDAO))
                    expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), expected]))
                    expect(m.trace.data.first?.tracedGas?.used).to(equal(2))
                    expect(m.trace.data.first?.tracedGas?.remaining).to(equal(8))
                    #if TRACE_STACK_INOUT
                    expect(m.trace.data.first?.stackOut).to(beEmpty())
                    expect(m.trace.data.first?.stackIn).to(equal([expected]))
                    #endif
                }
            }
            #endif
        }
    }
}
