@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSLoadSpec: QuickSpec {
    class StateHandler: TestHandler {
        let state: MemoryState

        init(state: MemoryState) {
            self.state = state
        }

        override func storage(address: H160, index: H256) -> H256 {
            storageRequests.append((address, index))
            return state.storage(address: address, index: index)
        }
    }

    private static var context: Machine.Context {
        Machine.Context(targetAddress: TestHandler.address1, callerAddress: TestHandler.address2, callValue: .ZERO)
    }

    private static var prices: [([HardFork], UInt64, UInt64)] {
        let forks = HardFork.allCases
        return [
            (Array(forks.prefix(while: { $0 != .Tangerine })), 50, 50),
            (Array(forks.drop(while: { $0 != .Tangerine }).prefix(while: { $0 != .Istanbul })), 200, 200),
            (Array(forks.drop(while: { $0 != .Istanbul }).prefix(while: { $0 != .Berlin })), 800, 800),
            (Array(forks.drop(while: { $0 != .Berlin })), 2100, 100)
        ]
    }

    override class func spec() {
        describe("Instruction SLOAD") {
            let address = TestHandler.address1
            let key = H256(from: (0 ..< 32).map { UInt8($0 + 1) })
            let word = U256(from: key)

            it("loads full-width keys and values at the exact price on every fork") {
                expect(Self.prices.flatMap { $0.0 }).to(equal(HardFork.allCases))
                let words: [U256] = [.ZERO, U256(from: 1), U256(from: UInt64.max), U256(from: 1) << 64,
                                     U256(from: 1) << 128, U256(from: 1) << 192, U256(from: 1) << 255, word, .MAX]
                for (group, cold, warm) in Self.prices {
                    for fork in group {
                        for prewarmed in [false, true] {
                            for index in words {
                                for value in words {
                                    let cost = prewarmed ? warm : cold
                                    let m = TestMachine.machine(opcode: .SLOAD, gasLimit: cost, context: Self.context, hardFork: fork)
                                    let handler = m.handler as! TestHandler
                                    let hashKey = H256(from: index)
                                    handler.storages[address] = [hashKey: H256(from: value)]
                                    if prewarmed {
                                        m.state.warm(address: address, index: hashKey)
                                    }
                                    expect(m.stack.push(value: U256(from: 77))).to(beSuccess())
                                    expect(m.stack.push(value: index)).to(beSuccess())
                                    let detail = "fork \(fork), warm \(prewarmed), index \(index), value \(value)"

                                    m.evalLoop()

                                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                                    expect(m.stack.data).to(equal([U256(from: 77), value]), description: detail)
                                    expect(m.gas.remaining).to(equal(0), description: detail)
                                    expect(handler.storageRequests.map(\.address)).to(equal([address]), description: detail)
                                    expect(handler.storageRequests.map(\.index)).to(equal([hashKey]), description: detail)
                                    expect(handler.storages[address]?[hashKey]).to(equal(H256(from: value)), description: detail)
                                    expect(m.state.accessed.storage.count).to(equal(prewarmed || cold == 2100 ? 1 : 0), description: detail)
                                    expect(m.state.accessed.addresses).to(beEmpty())
                                }
                            }
                        }
                    }
                }
            }

            it("preserves byte order and reads the target account, not its caller") {
                let m = TestMachine.machine(opcode: .SLOAD, gasLimit: 2100, context: Self.context, hardFork: .Berlin)
                let handler = m.handler as! TestHandler
                handler.storages[address] = [key: key]
                handler.storages[TestHandler.address2] = [key: .MAX]
                let literal = U256(from: [0x191a1b1c1d1e1f20, 0x1112131415161718,
                                          0x090a0b0c0d0e0f10, 0x0102030405060708])
                expect(m.stack.push(value: literal)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([literal]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.storageRequests.map(\.address)).to(equal([address]))
                expect(handler.storageRequests.map(\.index)).to(equal([key]))
            }

            it("returns zero for absent storage and permits static reads") {
                for (group, cold, _) in Self.prices {
                    for fork in group {
                        let handler = StaticHandler()
                        handler.storages[address] = [.ZERO: .MAX]
                        handler.storages[TestHandler.address2] = [key: .MAX]
                        let m = Machine(data: [], code: [Opcode.SLOAD.rawValue], gasLimit: cold, memoryLimit: 0,
                                        context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                        expect(m.stack.push(value: word)).to(beSuccess())
                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([.ZERO]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(handler.storageRequests.count).to(equal(1))
                        expect(handler.storages[address]?[key]).to(beNil())
                        expect(m.memory.effectiveLength).to(equal(0))
                        expect(m.gas.refunded).to(equal(0))
                    }
                }
            }

            it("rejects stack underflow before gas, warming or storage reads") {
                for fork in HardFork.allCases {
                    for budget: UInt64 in [0, 2100] {
                        let m = TestMachine.machine(opcode: .SLOAD, gasLimit: budget, context: Self.context, hardFork: fork)
                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                        expect(m.stack.data).to(beEmpty())
                        expect(m.gas.remaining).to(equal(budget))
                        expect(m.state.accessed.storage).to(beEmpty())
                        expect(m.state.accessed.addresses).to(beEmpty())
                        expect((m.handler as! TestHandler).storageRequests).to(beEmpty())
                    }
                }
            }

            it("fails one gas short without reading storage or consuming the key") {
                for (group, cold, warm) in Self.prices {
                    for fork in group {
                        for prewarmed in [false, true] {
                            for budget: UInt64 in [0, (prewarmed ? warm : cold) - 1] {
                                let m = TestMachine.machine(opcode: .SLOAD, gasLimit: budget, context: Self.context, hardFork: fork)
                                if prewarmed {
                                    m.state.warm(address: address, index: key)
                                }
                                m.gas.recordRefund(refund: 10000)
                                expect(m.stack.push(value: word)).to(beSuccess())

                                m.evalLoop()

                                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                                expect(m.stack.data).to(equal([word]))
                                expect(m.gas.remaining).to(equal(budget))
                                expect(m.gas.refunded).to(equal(10000))
                                expect(m.state.accessed.storage.count).to(equal(prewarmed || cold == 2100 ? 1 : 0))
                                expect(m.state.accessed.addresses).to(beEmpty())
                                expect((m.handler as! TestHandler).storageRequests).to(beEmpty())
                                expect(m.pc).to(equal(0))
                                m.evalLoop()
                                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                                expect((m.handler as! TestHandler).storageRequests).to(beEmpty())
                            }
                        }
                    }
                }
            }

            it("charges a repeated slot as warm without caching its value") {
                for fork in HardFork.allCases.drop(while: { $0 != .Berlin }) {
                    let m = Machine(data: [], code: [Opcode.SLOAD.rawValue, Opcode.SLOAD.rawValue], gasLimit: 2200, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: TestHandler(), hardFork: fork)
                    let handler = m.handler as! TestHandler
                    handler.storages[address] = [key: key]
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.step()

                    expect(m.gas.remaining).to(equal(100))
                    handler.storages[address] = [key: .MAX]

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([.MAX]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.storageRequests.map(\.index)).to(equal([key, key]))
                    expect(m.state.accessed.storage.count).to(equal(1))
                }
            }

            it("does not warm other keys or accounts, or use account warmth as slot warmth") {
                for fork in HardFork.allCases.drop(while: { $0 != .Berlin }) {
                    for otherIndex in [H256.ZERO, H256(from: U256(from: 1) << 255)] {
                        let m = TestMachine.machine(opcode: .SLOAD, gasLimit: 2100, context: Self.context, hardFork: fork)
                        m.state.warm(address: address)
                        m.state.warm(address: address, index: otherIndex)
                        m.state.warm(address: TestHandler.address2, index: key)
                        expect(m.stack.push(value: word)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([.ZERO]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.state.accessed.storage.count).to(equal(3))
                        expect(m.state.accessed.addresses).to(equal([address]))
                        expect((m.handler as! TestHandler).storageRequests.count).to(equal(1))
                    }
                }
            }

            it("uses parent slot warmth without inserting it into the child") {
                let parent = ExecutionState()
                parent.warm(address: address, index: key)
                let m = TestMachine.machine(opcode: .SLOAD, gasLimit: 100, context: Self.context, hardFork: .Berlin)
                m.state.parent = parent
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.state.accessed.storage).to(beEmpty())
                expect(parent.accessed.storage.count).to(equal(1))
                expect((m.handler as! TestHandler).storageRequests.count).to(equal(1))
            }

            it("replaces the top of a full stack") {
                let m = TestMachine.machine(opcode: .SLOAD, gasLimit: 2100, context: Self.context, hardFork: .Berlin)
                (m.handler as! TestHandler).storages[address] = [key: .MAX]
                for _ in 0 ..< m.stack.limit {
                    expect(m.stack.push(value: word)).to(beSuccess())
                }
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(Array(repeating: word, count: m.stack.limit - 1) + [.MAX]))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).storageRequests.count).to(equal(1))
            }

            it("reads overlays through substates before falling back to the backend") {
                let backend = MockBackend()
                backend.storages[address] = [key: key]
                let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Cancun)
                for value in [key, H256.MAX, .ZERO] {
                    if value != key {
                        state.setStorage(address: address, key: key, value: value)
                    }
                    state.enter(gasLimit: 2100, isStatic: true)
                    let handler = StateHandler(state: state)
                    let m = Machine(data: [], code: [Opcode.SLOAD.rawValue], gasLimit: 2100, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                    expect(m.stack.push(value: word)).to(beSuccess())
                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([U256(from: value)]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.storageRequests.map(\.index)).to(equal([key]))
                    expect(state.storages).to(beEmpty())
                    state.exitRevert()
                }
                expect(backend.storages[address]?[key]).to(equal(key))
            }

            #if TRACING
            it("traces the key, loaded value and cold storage cost") {
                let m = TestMachine.machine(opcode: .SLOAD, gasLimit: 2200, context: Self.context, hardFork: .Berlin)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: address))
                (m.handler as! TestHandler).storages[address] = [key: .MAX]
                expect(m.stack.push(value: word)).to(beSuccess())
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.data.first?.opcode).to(equal(.SLOAD))
                expect(m.trace.data.first?.stack?.data).to(equal([.MAX]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2100))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(100))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word]))
                expect(m.trace.data.first?.stackIn).to(equal([.MAX]))
                #endif
            }
            #endif
        }
    }
}
