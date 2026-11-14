@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionSStoreSpec: QuickSpec {
    class FailingHandler: TestHandler {
        override func setStorage(address: H160, index: H256, value: H256) -> Result<Void, Machine.ExitError> {
            setStorageRequests.append((address, index, value))
            return .failure(.OutOfFund)
        }
    }

    class StateHandler: TestHandler {
        let state: MemoryState

        init(state: MemoryState) {
            self.state = state
        }

        override func storage(address: H160, index: H256) -> H256 {
            state.storage(address: address, index: index)
        }

        override func originalStorage(address: H160, index: H256) -> H256 {
            state.originalStorage(address: address, index: index) ?? .ZERO
        }

        override func setStorage(address: H160, index: H256, value: H256) -> Result<Void, Machine.ExitError> {
            state.setStorage(address: address, key: index, value: value)
            return .success(())
        }
    }

    private static var context: Machine.Context {
        Machine.Context(targetAddress: TestHandler.address1, callerAddress: TestHandler.address2, callValue: .ZERO)
    }

    private static var eras: [[HardFork]] {
        let forks = HardFork.allCases
        return [Array(forks.prefix(while: { $0 != .Istanbul })), [.Istanbul], [.Berlin],
                Array(forks.drop(while: { $0 != .London }))]
    }

    override class func spec() {
        describe("Instruction SSTORE") {
            let address = TestHandler.address1
            let key = H256(from: (1 ... 32).map { UInt8($0) })
            let word = U256(from: key)

            it("meters write sequences against the transaction original on every fork") {
                // Two writes; expected opcode cost/refund for legacy, Istanbul, Berlin and London.
                let cases: [(UInt64, [UInt64], [(UInt64, Int64)])] = [
                    (0, [0, 0], [(10000, 0), (1600, 0), (2300, 0), (2300, 0)]),
                    (0, [1, 0], [(25000, 15000), (20800, 19200), (22200, 19900), (22200, 19900)]),
                    (0, [1, 2], [(25000, 0), (20800, 0), (22200, 0), (22200, 0)]),
                    (1, [0, 1], [(25000, 15000), (5800, 4200), (5100, 2800), (5100, 2800)]),
                    (1, [0, 2], [(25000, 15000), (5800, 0), (5100, 0), (5100, 0)]),
                    (1, [2, 0], [(10000, 15000), (5800, 15000), (5100, 15000), (5100, 4800)]),
                    (1, [2, 1], [(10000, 0), (5800, 4200), (5100, 2800), (5100, 2800)]),
                    (1, [0, 0], [(10000, 15000), (5800, 15000), (5100, 15000), (5100, 4800)])
                ]
                expect(Self.eras.flatMap { $0 }).to(equal(HardFork.allCases))
                for (era, forks) in Self.eras.enumerated() {
                    for fork in forks {
                        for (original, values, expected) in cases {
                            let handler = TestHandler()
                            handler.storages[address] = [key: H256(from: U256(from: original))]
                            handler.originalStorages = handler.storages
                            var code: [UInt8] = []
                            for value in values {
                                code += [Opcode.PUSH1.rawValue, UInt8(value), Opcode.PUSH32.rawValue]
                                code += key.BYTES
                                code.append(Opcode.SSTORE.rawValue)
                            }
                            let m = Machine(data: [], code: code, gasLimit: 100000, memoryLimit: 0,
                                            context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)

                            m.evalLoop()

                            let detail = "fork \(fork), original \(original), writes \(values)"
                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(beEmpty(), description: detail)
                            expect(m.gas.spent).to(equal(expected[era].0 + 12), description: detail)
                            expect(m.gas.refunded).to(equal(expected[era].1), description: detail)
                            expect(handler.storages[address]?[key]).to(equal(H256(from: U256(from: values[1]))), description: detail)
                            expect(handler.setStorageRequests.map(\.value)).to(equal(values.map { H256(from: U256(from: $0)) }), description: detail)
                            expect(handler.originalStorageRequests.count).to(equal(era == 0 ? 0 : 2), description: detail)
                            expect(m.state.accessed.storage.count).to(equal(era >= 2 ? 1 : 0), description: detail)
                            expect(m.state.accessed.addresses).to(beEmpty())
                        }
                    }
                }
            }

            it("stores all bytes of the key and value at the target address") {
                let m = TestMachine.machine(opcode: .SSTORE, gasLimit: 22100, context: Self.context, hardFork: .Berlin)
                let keyWord = U256(from: [0x191a1b1c1d1e1f20, 0x1112131415161718, 0x090a0b0c0d0e0f10, 0x0102030405060708])
                let valueWord = U256(from: [0x38393a3b3c3d3e3f, 0x3031323334353637, 0x28292a2b2c2d2e2f, 0x2021222324252627])
                let value = H256(from: (32 ... 63).map { UInt8($0) })
                expect(m.stack.push(value: U256(from: 77))).to(beSuccess())
                expect(m.stack.push(value: valueWord)).to(beSuccess())
                expect(m.stack.push(value: keyWord)).to(beSuccess())

                m.evalLoop()

                let handler = m.handler as! TestHandler
                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 77)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.setStorageRequests.map(\.address)).to(equal([address]))
                expect(handler.setStorageRequests.map(\.index)).to(equal([key]))
                expect(handler.setStorageRequests.map(\.value)).to(equal([value]))
                expect(handler.originalStorageRequests.map(\.index)).to(equal([key]))
                expect(handler.storageRequests.map(\.address)).to(equal([address]))
                expect(handler.storages[address]?[key]).to(equal(value))
                expect(handler.storages[TestHandler.address2]).to(beNil())
            }

            it("rejects stack underflow before static, gas or storage checks") {
                for fork in HardFork.allCases {
                    for count in 0 ... 1 {
                        let handler = StaticHandler()
                        let m = Machine(data: [], code: [Opcode.SSTORE.rawValue], gasLimit: 0, memoryLimit: 0,
                                        context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                        if count == 1 {
                            expect(m.stack.push(value: word)).to(beSuccess())
                        }
                        let stack = m.stack.data

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                        expect(m.stack.data).to(equal(stack))
                        expect(m.gas.remaining).to(equal(0))
                        expect(handler.storageRequests).to(beEmpty())
                        expect(handler.originalStorageRequests).to(beEmpty())
                        expect(handler.setStorageRequests).to(beEmpty())
                        expect(m.state.accessed.storage).to(beEmpty())
                    }
                }
            }

            it("rejects static writes even when the value is unchanged") {
                for fork in HardFork.allCases {
                    for budget: UInt64 in [0, 50000] {
                        let handler = StaticHandler()
                        handler.storages[address] = [key: .MAX]
                        let m = Machine(data: [], code: [Opcode.SSTORE.rawValue], gasLimit: budget, memoryLimit: 0,
                                        context: Self.context, state: ExecutionState(), handler: handler, hardFork: fork)
                        expect(m.stack.push(value: .MAX)).to(beSuccess())
                        expect(m.stack.push(value: word)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.WriteInStaticContext))))
                        expect(m.stack.data).to(equal([.MAX, word]))
                        expect(m.gas.remaining).to(equal(budget))
                        expect(m.gas.refunded).to(equal(0))
                        expect(handler.storageRequests).to(beEmpty())
                        expect(handler.originalStorageRequests).to(beEmpty())
                        expect(handler.setStorageRequests).to(beEmpty())
                        expect(m.state.accessed.storage).to(beEmpty())
                    }
                }
            }

            it("enforces the stipend sentry from Istanbul before reads or warming") {
                for fork in HardFork.allCases.drop(while: { $0 != .Istanbul }) {
                    for budget: UInt64 in [0, 2299, 2300, 2301] {
                        for warm in [false, true] {
                            let m = TestMachine.machine(opcode: .SSTORE, gasLimit: budget, context: Self.context, hardFork: fork)
                            if warm {
                                m.state.warm(address: address, index: key)
                            }
                            expect(m.stack.push(value: .ZERO)).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())

                            m.evalLoop()

                            let handler = m.handler as! TestHandler
                            if budget <= 2300 {
                                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                                expect(m.stack.data).to(equal([.ZERO, word]))
                                expect(m.gas.remaining).to(equal(budget))
                                expect(handler.storageRequests).to(beEmpty())
                                expect(handler.originalStorageRequests).to(beEmpty())
                                expect(handler.setStorageRequests).to(beEmpty())
                                expect(m.state.accessed.storage.count).to(equal(warm ? 1 : 0))
                            } else {
                                let cost: UInt64 = fork == .Istanbul ? 800 : (warm ? 100 : 2200)
                                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                                expect(m.stack.data).to(beEmpty())
                                expect(m.gas.remaining).to(equal(2301 - cost))
                                expect(handler.setStorageRequests.count).to(equal(1))
                            }
                            expect(m.gas.refunded).to(equal(0))
                        }
                    }
                }
                let m = TestMachine.machine(opcode: .SSTORE, gasLimit: 2300, context: Self.context, hardFork: .Constantinople)
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect((m.handler as! TestHandler).storageRequests.count).to(equal(1))
                expect((m.handler as! TestHandler).originalStorageRequests).to(beEmpty())
            }

            it("does not write or grant a clearing refund when gas is one short") {
                for (era, forks) in Self.eras.enumerated() {
                    for fork in forks {
                        for warm in [false, true] {
                            let cost: UInt64 = era < 2 || !warm ? 5000 : 2900
                            let m = TestMachine.machine(opcode: .SSTORE, gasLimit: cost - 1, context: Self.context, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.storages[address] = [key: .MAX]
                            handler.originalStorages = handler.storages
                            if warm {
                                m.state.warm(address: address, index: key)
                            }
                            m.gas.recordRefund(refund: 10000)
                            expect(m.stack.push(value: .ZERO)).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                            expect(m.stack.data).to(equal([.ZERO, word]))
                            expect(m.gas.remaining).to(equal(cost - 1))
                            expect(m.gas.refunded).to(equal(10000))
                            expect(handler.setStorageRequests).to(beEmpty())
                            expect(handler.storages[address]?[key]).to(equal(.MAX))
                            expect(m.state.accessed.storage.count).to(equal(warm || era >= 2 ? 1 : 0))
                        }
                    }
                }
            }

            it("propagates a write failure without refunding or consuming operands") {
                let handler = FailingHandler()
                handler.storages[address] = [key: .MAX]
                handler.originalStorages = handler.storages
                let m = Machine(data: [], code: [Opcode.SSTORE.rawValue], gasLimit: 6000, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .London)
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                expect(m.stack.data).to(equal([.ZERO, word]))
                expect(m.gas.remaining).to(equal(1000))
                expect(m.gas.refunded).to(equal(0))
                expect(handler.storages[address]?[key]).to(equal(.MAX))
                expect(handler.setStorageRequests.count).to(equal(1))
                expect(m.pc).to(equal(0))
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                expect(handler.setStorageRequests.count).to(equal(1))
            }

            it("uses a negative frame refund when restoring a slot cleared by a parent") {
                let handler = TestHandler()
                handler.storages[address] = [key: .ZERO]
                handler.originalStorages[address] = [key: .MAX]
                let parent = ExecutionState()
                parent.warm(address: address, index: key)
                let m = Machine(data: [], code: [Opcode.SSTORE.rawValue], gasLimit: 2301, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .London)
                m.state.parent = parent
                expect(m.stack.push(value: .MAX)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(2201))
                expect(m.gas.refunded).to(equal(-2000))
                expect(handler.storages[address]?[key]).to(equal(.MAX))
                expect(m.state.accessed.storage).to(beEmpty())
            }

            it("shares slot warmth with SLOAD in both orders") {
                for first in [Opcode.SLOAD, .SSTORE] {
                    let pushKey = [Opcode.PUSH32.rawValue] + key.BYTES
                    let load = pushKey + [Opcode.SLOAD.rawValue]
                    let store = [Opcode.PUSH1.rawValue, 1] + pushKey + [Opcode.SSTORE.rawValue]
                    let code = first == .SLOAD ? load + [Opcode.POP.rawValue] + store : store + load
                    let m = Machine(data: [], code: code, gasLimit: 30000, memoryLimit: 0,
                                    context: Self.context, state: ExecutionState(), handler: TestHandler(), hardFork: .Berlin)

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.gas.spent).to(equal(first == .SLOAD ? 22111 : 22209))
                    expect(m.stack.data).to(equal(first == .SLOAD ? [] : [U256(from: 1)]))
                    expect(m.state.accessed.storage.count).to(equal(1))
                    expect(m.state.accessed.addresses).to(beEmpty())
                }
            }

            it("consumes only two words from a full stack") {
                let m = TestMachine.machine(opcode: .SSTORE, gasLimit: 22100, context: Self.context, hardFork: .Berlin)
                for _ in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                }
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(Array(repeating: U256.MAX, count: m.stack.limit - 2)))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).storages[address]?[key]).to(equal(.MAX))
            }

            it("writes through MemoryState and keeps the transaction original across repeated writes") {
                let backend = MockBackend()
                backend.storages[address] = [key: .MAX]
                let state = MemoryState(gasLimit: 100000, backend: backend, hardFork: .London)
                let handler = StateHandler(state: state)
                let pushKey = [Opcode.PUSH32.rawValue] + key.BYTES
                var code = [Opcode.PUSH1.rawValue, 0] + pushKey + [Opcode.SSTORE.rawValue]
                code.append(Opcode.PUSH32.rawValue)
                code += Array(repeating: UInt8.max, count: 32)
                code += pushKey + [Opcode.SSTORE.rawValue]
                code += pushKey + [Opcode.SLOAD.rawValue]
                let m = Machine(data: [], code: code, gasLimit: 10000, memoryLimit: 0,
                                context: Self.context, state: ExecutionState(), handler: handler, hardFork: .London)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([.MAX]))
                expect(m.gas.spent).to(equal(5215))
                expect(m.gas.refunded).to(equal(2800))
                expect(backend.storages[address]?[key]).to(equal(.MAX))
                expect(state.originalStorage(address: address, index: key)).to(equal(.MAX))
            }

            #if TRACING
            it("traces both operands, the write cost and clearing refund") {
                let m = TestMachine.machine(opcode: .SSTORE, gasLimit: 6000, context: Self.context, hardFork: .London)
                let handler = m.handler as! TestHandler
                handler.storages[address] = [key: .MAX]
                handler.originalStorages = handler.storages
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: address))
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.data.first?.opcode).to(equal(.SSTORE))
                expect(m.trace.data.first?.stack?.data).to(beEmpty())
                expect(m.trace.data.first?.tracedGas?.used).to(equal(5000))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(1000))
                expect(m.gas.refunded).to(equal(4800))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word, .ZERO]))
                expect(m.trace.data.first?.stackIn).to(beEmpty())
                #endif
            }
            #endif
        }
    }
}
