@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionTStoreSpec: QuickSpec {
    class FailingHandler: TestHandler {
        override func tstore(address: H160, index: H256, value: U256) -> Result<Void, Machine.ExitError> {
            tstoreRequests.append((address, index, value))
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

        override func tstore(address: H160, index: H256, value: U256) -> Result<Void, Machine.ExitError> {
            tstoreRequests.append((address, index, value))
            state.setTStorage(address: address, key: index, value: H256(from: value))
            return .success(())
        }
    }

    private static var context: Machine.Context {
        Machine.Context(targetAddress: TestHandler.address1, callerAddress: TestHandler.address2, callValue: .ZERO)
    }

    override class func spec() {
        describe("Instruction TSTORE") {
            let address = TestHandler.address1
            let key = H256(from: (0 ..< 32).map { UInt8($0 + 1) })
            let word = U256(from: key)

            it("is unavailable before Cancun, before stack, static and gas checks") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Cancun })
                expect(forks.last).to(equal(.Shanghai))
                for fork in forks {
                    for budget: UInt64 in [0, 100] {
                        for count in 0 ... 2 {
                            let handler = StaticHandler()
                            let m = Machine(data: [], code: [Opcode.TSTORE.rawValue], gasLimit: budget, memoryLimit: 0,
                                            context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                            for _ in 0 ..< count {
                                expect(m.stack.push(value: word)).to(beSuccess())
                            }
                            let stack = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: "fork \(fork)")
                            expect(m.stack.data).to(equal(stack))
                            expect(m.gas.remaining).to(equal(budget))
                            expect(handler.tstoreRequests).to(beEmpty())
                            expect(handler.tstorages).to(beEmpty())
                        }
                    }
                }
            }

            it("stores full-width keys and values for exactly 100 gas on every active fork") {
                let forks = HardFork.allCases.drop(while: { $0 != .Cancun })
                expect(forks.first).to(equal(.Cancun))
                let words: [U256] = [.ZERO, U256(from: 1), U256(from: UInt64.max), U256(from: 1) << 64,
                                     U256(from: 1) << 128, U256(from: 1) << 192, U256(from: 1) << 255, word, .MAX]
                for fork in forks {
                    for index in words {
                        for value in words {
                            let m = TestMachine.machine(opcode: .TSTORE, gasLimit: 100, context: Self.context, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            expect(m.stack.push(value: U256(from: 77))).to(beSuccess())
                            expect(m.stack.push(value: value)).to(beSuccess())
                            expect(m.stack.push(value: index)).to(beSuccess())
                            let detail = "fork \(fork), index \(index), value \(value)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 77)]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(handler.tstoreRequests.map(\.address)).to(equal([address]), description: detail)
                            expect(handler.tstoreRequests.map(\.index)).to(equal([H256(from: index)]), description: detail)
                            expect(handler.tstoreRequests.map(\.value)).to(equal([value]), description: detail)
                            expect(handler.tstorages[address]?[H256(from: index)]).to(equal(value), description: detail)
                        }
                    }
                }
            }

            it("uses the top word as the big-endian key and writes only the target account") {
                let m = TestMachine.machine(opcode: .TSTORE, gasLimit: 100, context: Self.context, hardFork: .Cancun)
                let handler = m.handler as! TestHandler
                handler.tstorages[TestHandler.address2] = [key: .MAX]
                handler.tstorages[address] = [.ZERO: U256(from: 99)]
                let value = U256(from: [0xfedcba9876543210, 0x123456789abcdef0, 0x1111222233334444, 0xaaaabbbbccccdddd])
                expect(m.stack.push(value: value)).to(beSuccess())
                // Independent limbs fix the external byte order without reusing H256-to-U256 conversion.
                expect(m.stack.push(value: U256(from: [0x191a1b1c1d1e1f20, 0x1112131415161718,
                                                       0x090a0b0c0d0e0f10, 0x0102030405060708]))).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(beEmpty())
                expect(m.gas.remaining).to(equal(0))
                expect(handler.tstorages[address]).to(equal([.ZERO: U256(from: 99), key: value]))
                expect(handler.tstorages[TestHandler.address2]).to(equal([key: .MAX]))
                expect(handler.tstoreRequests.map(\.index)).to(equal([key]))
                expect(handler.tstoreRequests.map(\.value)).to(equal([value]))
            }

            it("rejects stack underflow before checking static context or gas") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for isStatic in [false, true] {
                        for count in 0 ... 1 {
                            let handler = isStatic ? StaticHandler() : TestHandler()
                            let m = Machine(data: [], code: [Opcode.TSTORE.rawValue], gasLimit: 0, memoryLimit: 0,
                                            context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                            if count == 1 {
                                expect(m.stack.push(value: word)).to(beSuccess())
                            }
                            let stack = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                            expect(m.stack.data).to(equal(stack))
                            expect(m.gas.remaining).to(equal(0))
                            expect(handler.tstoreRequests).to(beEmpty())
                        }
                    }
                }
            }

            it("rejects static writes, including zero and unchanged values, before charging") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for budget: UInt64 in [0, 99, 100, 1000] {
                        for value in [U256.ZERO, word, .MAX] {
                            let handler = StaticHandler()
                            handler.tstorages[address] = [key: value]
                            let m = Machine(data: [], code: [Opcode.TSTORE.rawValue], gasLimit: budget, memoryLimit: 0,
                                            context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                            expect(m.stack.push(value: value)).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.WriteInStaticContext))))
                            expect(m.stack.data).to(equal([value, word]))
                            expect(m.gas.remaining).to(equal(budget))
                            expect(handler.tstoreRequests).to(beEmpty())
                            expect(handler.tstorages[address]).to(equal([key: value]))
                        }
                    }
                }
            }

            it("does not write or consume operands when gas is insufficient, regardless of refunds") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for budget: UInt64 in [0, 99] {
                        let m = TestMachine.machine(opcode: .TSTORE, gasLimit: budget, context: Self.context, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.tstorages[address] = [key: word]
                        m.gas.recordRefund(refund: 1000)
                        expect(m.stack.push(value: .MAX)).to(beSuccess())
                        expect(m.stack.push(value: word)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.stack.data).to(equal([.MAX, word]))
                        expect(m.gas.remaining).to(equal(budget))
                        expect(m.gas.refunded).to(equal(1000))
                        expect(handler.tstoreRequests).to(beEmpty())
                        expect(handler.tstorages[address]).to(equal([key: word]))
                    }
                }
            }

            it("writes with at most 2300 gas left, exempt from the EIP-2200 sentry") {
                // EIP-1153: TSTORE is not subject to the EIP-2200 rule that fails SSTORE unless more than 2300 gas remains.
                for budget: UInt64 in [2299, 2300, 2301] {
                    let m = TestMachine.machine(opcode: .TSTORE, gasLimit: budget, context: Self.context, hardFork: .Cancun)
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "budget \(budget)")
                    expect(m.stack.data).to(beEmpty(), description: "budget \(budget)")
                    expect(m.gas.remaining).to(equal(budget - 100), description: "budget \(budget)")
                    expect((m.handler as! TestHandler).tstorages[address]?[key]).to(equal(.MAX), description: "budget \(budget)")
                }
            }

            it("charges exactly 100 gas at the largest gas limits") {
                for budget in [UInt64.max - 100, UInt64.max] {
                    let m = TestMachine.machine(opcode: .TSTORE, gasLimit: budget, context: Self.context, hardFork: .Cancun)
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "budget \(budget)")
                    expect(m.stack.data).to(beEmpty(), description: "budget \(budget)")
                    expect(m.gas.remaining).to(equal(budget - 100), description: "budget \(budget)")
                    expect((m.handler as! TestHandler).tstorages[address]?[key]).to(equal(.MAX), description: "budget \(budget)")
                }
            }

            it("consumes two operands from a full stack") {
                let m = TestMachine.machine(opcode: .TSTORE, gasLimit: 100, context: Self.context, hardFork: .Cancun)
                for _ in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                }
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(Array(repeating: .MAX, count: m.stack.limit - 2)))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).tstorages[address]?[key]).to(equal(.MAX))
            }

            it("overwrites and clears a slot without refunds, memory changes or warming") {
                for warm in [false, true] {
                    let handler = TestHandler()
                    let state = ExecutionState()
                    if warm {
                        state.accessed.addresses.insert(address)
                        state.accessed.storage.insert(.init(address: address, key: key))
                    }
                    let addresses = state.accessed.addresses
                    let storage = state.accessed.storage
                    for value in [word, word, U256.MAX, .ZERO] {
                        let m = Machine(data: [], code: [Opcode.TSTORE.rawValue], gasLimit: 103, memoryLimit: 32,
                                        context: Self.context, state: state, handler: handler, hardFork: .Cancun)
                        expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                        expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                        let memory = m.memory.get(offset: 0, size: 32)
                        let memoryGas = m.gas.memoryGas
                        m.gas.recordRefund(refund: 500)
                        expect(m.stack.push(value: value)).to(beSuccess())
                        expect(m.stack.push(value: word)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(beEmpty())
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.gas.refunded).to(equal(500))
                        expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                        expect(m.gas.memoryGas).to(equal(memoryGas))
                        expect(handler.tstorages[address]).to(equal([key: value]))
                        expect(state.accessed.addresses).to(equal(addresses))
                        expect(state.accessed.storage).to(equal(storage))
                    }
                    expect(handler.tstoreRequests.map(\.value)).to(equal([word, word, .MAX, .ZERO]))
                    expect(handler.tloadRequests).to(beEmpty())
                }
            }

            it("propagates the handler error after charging without consuming operands or retrying") {
                let handler = FailingHandler()
                handler.tstorages[address] = [key: word]
                let m = Machine(data: [], code: [Opcode.TSTORE.rawValue], gasLimit: 1000, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                expect(m.stack.push(value: .MAX)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()
                m.step()
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                expect(m.stack.data).to(equal([.MAX, word]))
                expect(m.gas.remaining).to(equal(900))
                expect(m.pc).to(equal(0))
                expect(handler.tstoreRequests.map(\.address)).to(equal([address]))
                expect(handler.tstoreRequests.map(\.index)).to(equal([key]))
                expect(handler.tstoreRequests.map(\.value)).to(equal([.MAX]))
                expect(handler.tstorages[address]).to(equal([key: word]))
            }

            it("stores, overwrites and clears slots that TLOAD reads back without touching persistent storage") {
                let backend = MockBackend()
                backend.storages[address] = [key: .MAX]
                let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: .Cancun)
                let handler = StateHandler(state: state)
                let other = H256(from: (0 ..< 32).map { UInt8(0xff - $0) })
                let stored = U256(from: 0x1234)
                let push32: (H256) -> [UInt8] = { [Opcode.PUSH32.rawValue] + $0.BYTES }
                var code: [UInt8] = []
                code += push32(H256(from: stored)) + push32(key) + [Opcode.TSTORE.rawValue]
                code += push32(key) + [Opcode.TLOAD.rawValue]
                code += push32(.MAX) + push32(other) + [Opcode.TSTORE.rawValue]
                code += [Opcode.PUSH1.rawValue, 0] + push32(key) + [Opcode.TSTORE.rawValue]
                code += push32(key) + [Opcode.TLOAD.rawValue] + push32(other) + [Opcode.TLOAD.rawValue]
                // Eight PUSH32 and one PUSH1 cost 27; three TSTORE and three TLOAD cost 600.
                let m = Machine(data: [], code: code, gasLimit: 627, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([stored, .ZERO, .MAX]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.tstoreRequests.map(\.index)).to(equal([key, other, key]))
                expect(handler.tstoreRequests.map(\.value)).to(equal([stored, .MAX, .ZERO]))
                expect(handler.tloadRequests.map(\.index)).to(equal([key, key, other]))
                expect(state.getTStorage(address: address, key: key)).to(equal(.ZERO))
                expect(state.getTStorage(address: address, key: other)).to(equal(.MAX))
                expect(state.storages).to(beEmpty())
                expect(state.accounts).to(beEmpty())
                expect(backend.storages[address]?[key]).to(equal(.MAX))
                expect(backend.basicRequests).to(beEmpty())
            }

            it("keeps a nested write only when the substate commits, as TLOAD observes") {
                for ending in [Opcode.STOP, .REVERT, .INVALID] {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: .Cancun)
                    let handler = StateHandler(state: state)
                    state.setTStorage(address: address, key: key, value: key)
                    state.enter(gasLimit: 106, isStatic: false)
                    let code: [UInt8] = [Opcode.TSTORE.rawValue, Opcode.PUSH1.rawValue, 0, Opcode.PUSH1.rawValue, 0, ending.rawValue]
                    let m = Machine(data: [], code: code, gasLimit: 106, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    // The write is visible inside the frame; executor finalization is explicit in this integration test.
                    expect(state.getTStorage(address: address, key: key)).to(equal(.MAX), description: "ending \(ending)")
                    let kept: H256
                    switch ending {
                    case .STOP:
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        state.exitCommit()
                        kept = .MAX
                    case .REVERT:
                        expect(m.machineStatus).to(equal(.Exit(.Revert)))
                        state.exitRevert()
                        kept = key
                    default:
                        expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidOpcode(ending.rawValue)))))
                        state.exitDiscard()
                        kept = key
                    }

                    let reader = Machine(data: [], code: [Opcode.TLOAD.rawValue], gasLimit: 100, memoryLimit: 0,
                                         context: Self.context, state: ExecutionState(), handler: handler, hardFork: .Cancun)
                    expect(reader.stack.push(value: word)).to(beSuccess())

                    reader.evalLoop()

                    expect(reader.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "ending \(ending)")
                    expect(reader.stack.data).to(equal([U256(from: kept)]), description: "ending \(ending)")
                    expect(state.getTStorage(address: address, key: key)).to(equal(kept), description: "ending \(ending)")
                    expect(handler.tstoreRequests.map(\.value)).to(equal([.MAX]), description: "ending \(ending)")
                    expect(handler.tloadRequests.map(\.index)).to(equal([key]), description: "ending \(ending)")
                    expect(state.storages).to(beEmpty(), description: "ending \(ending)")
                    expect(backend.basicRequests).to(beEmpty(), description: "ending \(ending)")
                }
            }

            #if TRACING
            it("traces the key and value without a stack result") {
                let m = TestMachine.machine(opcode: .TSTORE, gasLimit: 150, context: Self.context, hardFork: .Cancun)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: address))
                expect(m.stack.push(value: .MAX)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.data.first?.opcode).to(equal(.TSTORE))
                expect(m.trace.data.first?.stack?.data).to(beEmpty())
                expect(m.trace.data.first?.tracedGas?.used).to(equal(100))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(50))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word, .MAX]))
                expect(m.trace.data.first?.stackIn).to(beEmpty())
                #endif
            }
            #endif
        }
    }
}
