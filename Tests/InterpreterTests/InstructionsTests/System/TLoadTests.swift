@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionTLoadSpec: QuickSpec {
    class FailingHandler: TestHandler {
        override func tload(address: H160, index: H256) -> Result<U256, Machine.ExitError> {
            tloadRequests.append((address, index))
            return .failure(.OutOfFund)
        }
    }

    class StateHandler: TestHandler {
        let state: MemoryState

        init(state: MemoryState) {
            self.state = state
        }

        override func tload(address: H160, index: H256) -> Result<U256, Machine.ExitError> {
            tloadRequests.append((address, index))
            return .success(U256(from: state.getTStorage(address: address, key: index)))
        }
    }

    private static var context: Machine.Context {
        Machine.Context(targetAddress: TestHandler.address1, callerAddress: TestHandler.address2, callValue: .ZERO)
    }

    override class func spec() {
        describe("Instruction TLOAD") {
            let address = TestHandler.address1
            let key = H256(from: (0 ..< 32).map { UInt8($0 + 1) })
            let word = U256(from: key)

            it("is unavailable before Cancun, before checking stack or gas") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Cancun })
                expect(forks.last).to(equal(.Shanghai))
                for fork in forks {
                    for budget: UInt64 in [0, 100] {
                        for hasKey in [false, true] {
                            let m = TestMachine.machine(opcode: .TLOAD, gasLimit: budget, context: Self.context, hardFork: fork)
                            if hasKey {
                                expect(m.stack.push(value: word)).to(beSuccess())
                            }
                            let original = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: "fork \(fork)")
                            expect(m.stack.data).to(equal(original))
                            expect(m.gas.remaining).to(equal(budget))
                            expect((m.handler as! TestHandler).tloadRequests).to(beEmpty())
                        }
                    }
                }
            }

            it("loads full-width keys and values for exactly 100 gas on every active fork") {
                let forks = HardFork.allCases.drop(while: { $0 != .Cancun })
                expect(forks.first).to(equal(.Cancun))
                let words: [U256] = [.ZERO, U256(from: 1), U256(from: UInt64.max), U256(from: 1) << 64,
                                     U256(from: 1) << 128, U256(from: 1) << 192, U256(from: 1) << 255, word, .MAX]
                for fork in forks {
                    for index in words {
                        for value in words {
                            let m = TestMachine.machine(opcode: .TLOAD, gasLimit: 100, context: Self.context, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.tstorages[address] = [H256(from: index): value]
                            expect(m.stack.push(value: U256(from: 77))).to(beSuccess())
                            expect(m.stack.push(value: index)).to(beSuccess())
                            let detail = "fork \(fork), index \(index), value \(value)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 77), value]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(handler.tloadRequests.map(\.address)).to(equal([address]), description: detail)
                            expect(handler.tloadRequests.map(\.index)).to(equal([H256(from: index)]), description: detail)
                            expect(handler.tstorages[address]?[H256(from: index)]).to(equal(value), description: detail)
                        }
                    }
                }
            }

            it("passes all key bytes in big-endian order and uses the target, not the caller") {
                let m = TestMachine.machine(opcode: .TLOAD, gasLimit: 100, context: Self.context, hardFork: .Cancun)
                let handler = m.handler as! TestHandler
                handler.tstorages[address] = [key: U256(from: 42)]
                handler.tstorages[TestHandler.address2] = [key: .MAX]
                // An independent limb literal detects byte reversal or key truncation.
                expect(m.stack.push(value: U256(from: [0x191a1b1c1d1e1f20, 0x1112131415161718,
                                                       0x090a0b0c0d0e0f10, 0x0102030405060708]))).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 42)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.tloadRequests.map(\.address)).to(equal([address]))
                expect(handler.tloadRequests.map(\.index)).to(equal([key]))
            }

            it("returns zero for an unset slot without reading another account or key") {
                let m = TestMachine.machine(opcode: .TLOAD, gasLimit: 100, context: Self.context, hardFork: .Cancun)
                let handler = m.handler as! TestHandler
                handler.tstorages[address] = [.ZERO: .MAX]
                handler.tstorages[TestHandler.address2] = [key: .MAX]
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.tloadRequests.count).to(equal(1))
                expect(handler.tstorages[address]?[key]).to(beNil())
            }

            it("rejects stack underflow before charging or reading transient storage") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for budget: UInt64 in [0, 100] {
                        let m = TestMachine.machine(opcodes: [.TLOAD], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                        expect(m.stack.data).to(beEmpty())
                        expect(m.gas.remaining).to(equal(budget))
                        expect((m.handler as! TestHandler).tloadRequests).to(beEmpty())
                    }
                }
            }

            it("preserves the key on insufficient gas and cannot spend refunds") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for budget: UInt64 in [0, 99] {
                        let m = TestMachine.machine(opcodes: [.TLOAD], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                        m.gas.recordRefund(refund: 1000)
                        expect(m.stack.push(value: word)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.stack.data).to(equal([word]))
                        expect(m.gas.remaining).to(equal(budget))
                        expect(m.gas.refunded).to(equal(1000))
                        expect((m.handler as! TestHandler).tloadRequests).to(beEmpty())
                    }
                }
            }

            it("replaces the top of a full stack") {
                let m = TestMachine.machine(opcodes: [.TLOAD], gasLimit: 100, memoryLimit: 0, hardFork: .Cancun)
                for _ in 0 ..< m.stack.limit {
                    expect(m.stack.push(value: word)).to(beSuccess())
                }

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(Array(repeating: word, count: m.stack.limit - 1) + [.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).tloadRequests.count).to(equal(1))
            }

            it("is allowed in static calls with only 100 gas") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    let handler = StaticHandler()
                    handler.tstorages[address] = [key: .MAX]
                    let m = Machine(data: [], code: [Opcode.TLOAD.rawValue], gasLimit: 100, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([.MAX]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.tloadRequests.map(\.address)).to(equal([address]))
                }
            }

            it("charges each read without warming accounts or storage or changing memory and refunds") {
                for warm in [false, true] {
                    let m = TestMachine.machine(opcodes: [.TLOAD, .TLOAD, .TLOAD], gasLimit: 302, context: Self.context, hardFork: .Cancun)
                    let handler = m.handler as! TestHandler
                    handler.tstorages[address] = [key: word]
                    if warm {
                        m.state.accessed.addresses.insert(address)
                        m.state.accessed.storage.insert(.init(address: address, key: key))
                    }
                    let addresses = m.state.accessed.addresses
                    let storage = m.state.accessed.storage
                    expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                    expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                    let memory = m.memory.get(offset: 0, size: 32)
                    let memoryGas = m.gas.memoryGas
                    m.gas.recordRefund(refund: 500)
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal([word]))
                    expect(m.gas.remaining).to(equal(99))
                    expect(m.gas.refunded).to(equal(500))
                    expect(handler.tloadRequests.map(\.index)).to(equal([key, key]))
                    expect(m.state.accessed.addresses).to(equal(addresses))
                    expect(m.state.accessed.storage).to(equal(storage))
                    expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                    expect(m.gas.memoryGas).to(equal(memoryGas))
                }
            }

            it("propagates the handler error after charging, without consuming the key or resuming") {
                let handler = FailingHandler()
                let m = Machine(data: [], code: [Opcode.TLOAD.rawValue], gasLimit: 1000, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()
                m.step()
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                expect(m.stack.data).to(equal([word]))
                expect(m.gas.remaining).to(equal(900))
                expect(m.pc).to(equal(0))
                expect(handler.tloadRequests.map(\.address)).to(equal([address]))
                expect(handler.tloadRequests.map(\.index)).to(equal([key]))
            }

            it("reads existing MemoryState transient storage independently of persistent storage") {
                let backend = MockBackend()
                backend.storages[address] = [key: .MAX]
                let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: .Cancun)
                let handler = StateHandler(state: state)
                for value: H256? in [nil, .ZERO, key, .MAX] {
                    if let value {
                        state.setTStorage(address: address, key: key, value: value)
                    }
                    let m = Machine(data: [], code: [Opcode.TLOAD.rawValue], gasLimit: 100, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([U256(from: value ?? .ZERO)]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(state.getTStorage(address: address, key: key)).to(equal(value ?? .ZERO))
                    expect(state.accounts).to(beEmpty())
                    expect(state.storages).to(beEmpty())
                }
                expect(backend.storages[address]?[key]).to(equal(.MAX))
                expect(backend.basicRequests).to(beEmpty())
            }

            #if TRACING
            it("traces the key, loaded value and fixed gas cost") {
                let m = TestMachine.machine(opcode: .TLOAD, gasLimit: 150, context: Self.context, hardFork: .Cancun)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: address))
                (m.handler as! TestHandler).tstorages[address] = [key: .MAX]
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.data.first?.opcode).to(equal(.TLOAD))
                expect(m.trace.data.first?.stack?.data).to(equal([.MAX]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(100))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(50))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word]))
                expect(m.trace.data.first?.stackIn).to(equal([.MAX]))
                #endif
            }
            #endif
        }
    }
}
