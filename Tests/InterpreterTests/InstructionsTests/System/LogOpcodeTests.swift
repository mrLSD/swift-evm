@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionLogSpec: QuickSpec {
    class CustomHandler: TestHandler {
        var staticCall = false
        var error: Machine.ExitError?
        var logCalls = 0

        override func isStatic() -> Bool {
            staticCall
        }

        override func log(address: H160, topics: [H256], data: [UInt8]) -> Result<Void, Machine.ExitError> {
            logCalls += 1
            if let error {
                return .failure(error)
            }

            return super.log(address: address, topics: topics, data: data)
        }
    }

    class StateHandler: TestHandler {
        let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

        override func isStatic() -> Bool {
            state.metadata.isStatic
        }

        override func log(address: H160, topics: [H256], data: [UInt8]) -> Result<Void, Machine.ExitError> {
            state.log(address: address, topics: topics, data: data)
            return .success(())
        }
    }

    private static let topicWords: [U256] = [
        U256(from: [0x18191a1b1c1d1e1f, 0x1011121314151617, 0x08090a0b0c0d0e0f, 0x0001020304050607]),
        .MAX, .ZERO, U256(from: 1)
    ]

    private static let topics: [H256] = [
        H256(from: Array(0 ... 31)),
        H256(from: [UInt8](repeating: 0xff, count: 32)),
        H256.ZERO,
        H256(from: [UInt8](repeating: 0, count: 31) + [1])
    ]

    private static func pushArguments(_ m: Machine, offset: U256, size: U256, n: Int) {
        for topic in topicWords.prefix(n).reversed() {
            expect(m.stack.push(value: topic)).to(beSuccess())
        }

        expect(m.stack.push(value: size)).to(beSuccess())
        expect(m.stack.push(value: offset)).to(beSuccess())
    }

    override class func spec() {
        describe("Instructions LOG0-LOG4") {
            for n in 0 ... 4 {
                context("LOG\(n)") {
                    let base = UInt64(375 + 375 * n)

                    it("emits the target address, memory slice and ordered big-endian topics") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        let context = Machine.Context(targetAddress: TestHandler.address1, callerAddress: TestHandler.address2, callValue: U256(from: 9))
                        let m = TestMachine.machineWithContext(opcode: opcode, gasLimit: 3000, context: context)
                        let handler = m.handler as! TestHandler

                        expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                        expect(m.memory.set(offset: 0, value: Array(0 ... 31), size: 32)).to(beSuccess())
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        Self.pushArguments(m, offset: U256(from: 2), size: U256(from: 4), n: n)

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(handler.logs).to(equal([Log(address: context.targetAddress, topics: Array(Self.topics.prefix(n)), data: [2, 3, 4, 5])]))
                        expect(m.stack.data).to(equal([U256(from: 99)]))
                        expect(m.gas.remaining).to(equal(3000 - 3 - base - 32))
                        expect(m.memory.get(offset: 0, size: 32)).to(equal(Array(0 ... 31)))
                        expect(m.memory.effectiveLength).to(equal(32))
                        expect(m.gas.memoryGas.gasCost).to(equal(3))
                        expect(m.pc).to(equal(1))
                    }

                    it("emits empty data without inspecting the offset or expanding memory") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for offset in [U256.ZERO, U256(from: UInt64.max), U256.MAX] {
                            let m = TestMachine.machine(opcode: opcode, gasLimit: base)
                            let handler = m.handler as! TestHandler
                            Self.pushArguments(m, offset: offset, size: .ZERO, n: n)

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "offset \(offset)")
                            expect(handler.logs).to(equal([Log(address: H160.ZERO, topics: Array(Self.topics.prefix(n)), data: [])]))
                            expect(m.stack.length).to(equal(0))
                            expect(m.gas.remaining).to(equal(0))
                            expect(m.gas.memoryGas.gasCost).to(equal(0))
                            expect(m.memory.effectiveLength).to(equal(0))
                            expect(m.pc).to(equal(1))
                        }
                    }

                    it("charges exact memory expansion including the quadratic term") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        let cases: [(Int, Int, Int, UInt64)] = [
                            (0, 1, 32, 3), (0, 31, 32, 3), (0, 32, 32, 3), (0, 33, 64, 6),
                            (31, 1, 32, 3), (31, 2, 64, 6), (32, 1, 64, 6),
                            (100, 40, 160, 15), (704, 1, 736, 70), (16383, 2, 16416, 2053)
                        ]
                        for (offset, size, length, memoryCost) in cases {
                            let cost = base + UInt64(size * 8) + memoryCost
                            let m = TestMachine.machine(opcode: opcode, gasLimit: cost)
                            let handler = m.handler as! TestHandler
                            Self.pushArguments(m, offset: U256(from: UInt64(offset)), size: U256(from: UInt64(size)), n: n)
                            let description = "offset \(offset), size \(size)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: description)
                            expect(handler.logs).to(equal([Log(address: H160.ZERO, topics: Array(Self.topics.prefix(n)), data: [UInt8](repeating: 0, count: size))]), description: description)
                            expect(m.gas.remaining).to(equal(0), description: description)
                            expect(m.gas.memoryGas.gasCost).to(equal(memoryCost), description: description)
                            expect(m.memory.effectiveLength).to(equal(length), description: description)
                            expect(m.stack.length).to(equal(0), description: description)
                            expect(m.pc).to(equal(1), description: description)
                        }
                    }

                    it("reads unaligned slices with zero padding and charges only new memory words") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for offset in [0, 1, 31, 32, 63, 95, 96, 127] {
                            for size in [0, 1, 31, 32, 33, 65] {
                                let m = TestMachine.machine(opcode: opcode, gasLimit: 5000)
                                let handler = m.handler as! TestHandler
                                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 96)).to(beTrue())
                                expect(m.memory.set(offset: 0, value: Array(0 ..< 96), size: 96)).to(beSuccess())
                                Self.pushArguments(m, offset: U256(from: UInt64(offset)), size: U256(from: UInt64(size)), n: n)
                                let expected = (offset ..< offset + size).map { $0 < 96 ? UInt8($0) : 0 }
                                let words = size == 0 ? 3 : max(3, (offset + size + 31) / 32)
                                let description = "offset \(offset), size \(size)"

                                m.evalLoop()

                                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: description)
                                expect(handler.logs).to(equal([Log(address: H160.ZERO, topics: Array(Self.topics.prefix(n)), data: expected)]), description: description)
                                expect(m.gas.remaining).to(equal(5000 - base - UInt64(size * 8 + words * 3)), description: description)
                                expect(m.memory.effectiveLength).to(equal(words * 32), description: description)
                                expect(m.stack.length).to(equal(0), description: description)
                            }
                        }
                    }

                    it("fails without emitting when base, data or memory gas is insufficient") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for (size, gasLimit, remaining) in [(0, base - 1, base - 1), (1, base + 7, base + 7), (1, base + 10, UInt64(2))] {
                            let m = TestMachine.machine(opcode: opcode, gasLimit: gasLimit)
                            let handler = m.handler as! TestHandler
                            Self.pushArguments(m, offset: .ZERO, size: U256(from: UInt64(size)), n: n)
                            let original = m.stack.data
                            let description = "size \(size), gas \(gasLimit)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: description)
                            expect(handler.logs).to(beEmpty(), description: description)
                            expect(m.stack.data).to(equal(original), description: description)
                            expect(m.gas.remaining).to(equal(remaining), description: description)
                            expect(m.memory.effectiveLength).to(equal(0), description: description)
                            expect(m.pc).to(equal(0), description: description)
                        }
                    }

                    it("checks every missing argument before consuming stack or gas") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for count in 0 ..< 2 + n {
                            let m = TestMachine.machine(opcode: opcode, gasLimit: 3000)
                            let handler = m.handler as! TestHandler
                            for value in 0 ..< count {
                                expect(m.stack.push(value: U256(from: UInt64(value)))).to(beSuccess())
                            }
                            let original = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))), description: "stack count \(count)")
                            expect(handler.logs).to(beEmpty())
                            expect(m.stack.data).to(equal(original))
                            expect(m.gas.remaining).to(equal(3000))
                            expect(m.memory.effectiveLength).to(equal(0))
                            expect(m.pc).to(equal(0))
                        }
                    }

                    it("rejects empty and nonempty logs in a static call") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for size: UInt64 in [0, 1] {
                            let handler = CustomHandler()
                            handler.staticCall = true
                            let m = Machine(data: [], code: [opcode.rawValue], gasLimit: 3000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                            Self.pushArguments(m, offset: .ZERO, size: U256(from: size), n: n)
                            let original = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.WriteInStaticContext))))
                            expect(handler.logs).to(beEmpty())
                            expect(handler.logCalls).to(equal(0))
                            expect(m.stack.data).to(equal(original))
                            expect(m.gas.remaining).to(equal(3000))
                            expect(m.memory.effectiveLength).to(equal(0))
                            expect(m.pc).to(equal(0))
                        }
                    }

                    it("propagates a handler failure without appending a log or continuing execution") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        let handler = CustomHandler()
                        handler.error = .OutOfFund
                        let previous = Log(address: TestHandler.address2, topics: [], data: [0xaa])
                        handler.logs = [previous]
                        let m = Machine(data: [], code: [opcode.rawValue, Opcode.GAS.rawValue], gasLimit: 3000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                        Self.pushArguments(m, offset: .ZERO, size: U256(from: 1), n: n)

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                        expect(handler.logs).to(equal([previous]))
                        expect(handler.logCalls).to(equal(1))
                        expect(m.stack.length).to(equal(0))
                        expect(m.gas.remaining).to(equal(3000 - base - 11))
                        expect(m.pc).to(equal(0))
                    }

                    it("consumes only its arguments from a full stack") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        let m = TestMachine.machine(opcode: opcode, gasLimit: base)
                        for _ in 0 ..< m.stack.limit - 2 - n {
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        }

                        let original = m.stack.data
                        Self.pushArguments(m, offset: .ZERO, size: .ZERO, n: n)

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal(original))
                        expect((m.handler as! TestHandler).logs.count).to(equal(1))
                        expect(m.gas.remaining).to(equal(0))
                    }

                    it("is available from Frontier in every supported hard fork") {
                        let opcode = Opcode(rawValue: 0xa0 + UInt8(n))!
                        for hardFork in HardFork.allCases {
                            let m = TestMachine.machine(opcode: opcode, gasLimit: base, context: TestMachine.defaultContext(), hardFork: hardFork)
                            Self.pushArguments(m, offset: .ZERO, size: .ZERO, n: n)

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "hard fork \(hardFork)")
                            expect((m.handler as! TestHandler).logs).to(equal([Log(address: H160.ZERO, topics: Array(Self.topics.prefix(n)), data: [])]))
                            expect(m.gas.remaining).to(equal(0))
                            expect(m.stack.length).to(equal(0))
                        }
                    }
                }
            }

            it("rejects unrepresentable lengths, offsets and overflowing memory ranges") {
                let tooLarge = U256(from: UInt64(Int.max)) + U256(from: 1)
                let cases: [(U256, U256, UInt64)] = [
                    (.ZERO, tooLarge, 0), (.ZERO, .MAX, 0),
                    (tooLarge, U256(from: 1), 383), (.MAX, U256(from: 1), 383),
                    (U256(from: UInt64(Int.max)), U256(from: 1), 383),
                    (U256(from: UInt64.max / 2 - 1), U256(from: 1), 383)
                ]
                for (offset, size, spent) in cases {
                    let m = TestMachine.machine(opcode: .LOG0, gasLimit: UInt64.max)
                    Self.pushArguments(m, offset: offset, size: size, n: 0)
                    let original = m.stack.data
                    let description = "offset \(offset), size \(size)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: description)
                    expect((m.handler as! TestHandler).logs).to(beEmpty(), description: description)
                    expect(m.stack.data).to(equal(original), description: description)
                    expect(m.gas.remaining).to(equal(UInt64.max - spent), description: description)
                    expect(m.memory.effectiveLength).to(equal(0), description: description)
                    expect(m.pc).to(equal(0), description: description)
                }
            }

            #if arch(arm64) || arch(x86_64)
            it("rejects gas arithmetic overflow before allocating memory") {
                for size in [(UInt64.max - 375) / 8 + 1, UInt64.max / 8 + 1] {
                    let m = TestMachine.machine(opcode: .LOG0, gasLimit: UInt64.max)
                    Self.pushArguments(m, offset: .ZERO, size: U256(from: size), n: 0)
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: "size \(size)")
                    expect((m.handler as! TestHandler).logs).to(beEmpty())
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(UInt64.max))
                    expect(m.memory.effectiveLength).to(equal(0))
                }
            }
            #endif

            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            it("does not emit on allocation or reallocation failure") {
                for initialized in [false, true] {
                    let memory = FailingAllocationMemory()
                    let handler = CustomHandler()
                    let m = Machine(data: [], code: [Opcode.LOG0.rawValue], gasLimit: 1000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, memory: memory)
                    if initialized {
                        expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                        expect(memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                    }
                    memory.failAllocations = true
                    Self.pushArguments(m, offset: U256(from: 32), size: U256(from: 1), n: 0)
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(handler.logCalls).to(equal(0))
                    expect(handler.logs).to(beEmpty())
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(611))
                    expect(memory.effectiveLength).to(equal(initialized ? 32 : 0))
                    expect(memory.get(offset: 0, size: 1)).to(equal([initialized ? 0xab : 0]))
                }
            }
            #endif

            it("keeps event order and independent data snapshots across MSTORE8 instructions") {
                let code: [UInt8] = [
                    Opcode.PUSH1.rawValue, 0xab, Opcode.PUSH1.rawValue, 0, Opcode.MSTORE8.rawValue,
                    Opcode.PUSH1.rawValue, 1, Opcode.PUSH1.rawValue, 0, Opcode.LOG0.rawValue,
                    Opcode.PUSH1.rawValue, 0xcd, Opcode.PUSH1.rawValue, 0, Opcode.MSTORE8.rawValue,
                    Opcode.PUSH1.rawValue, 1, Opcode.PUSH1.rawValue, 0, Opcode.LOG0.rawValue
                ]
                let m = TestMachine.machine(rawCode: code, gasLimit: 1000)
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(handler.logs).to(equal([
                    Log(address: H160.ZERO, topics: [], data: [0xab]),
                    Log(address: H160.ZERO, topics: [], data: [0xcd])
                ]))
                expect(m.memory.get(offset: 0, size: 1)).to(equal([0xcd]))
                expect(m.gas.remaining).to(equal(201))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.stack.length).to(equal(0))
                expect(m.pc).to(equal(code.count))
            }

            it("charges LOG2 after MSTORE without paying for the same memory twice") {
                let code = [Opcode.PUSH32.rawValue] + [UInt8](repeating: 0xab, count: 32) + [
                    Opcode.PUSH1.rawValue, 0, Opcode.MSTORE.rawValue,
                    Opcode.PUSH1.rawValue, 2, Opcode.PUSH1.rawValue, 1,
                    Opcode.PUSH1.rawValue, 4, Opcode.PUSH1.rawValue, 2, Opcode.LOG2.rawValue
                ]
                let m = TestMachine.machine(rawCode: code, gasLimit: 2000)
                let handler = m.handler as! TestHandler

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let topics = [1, 2].map { H256(from: [UInt8](repeating: 0, count: 31) + [UInt8($0)]) }
                expect(handler.logs).to(equal([Log(address: H160.ZERO, topics: topics, data: [UInt8](repeating: 0xab, count: 4))]))
                // Six PUSHes, MSTORE and memory cost 24; LOG2 costs 1157.
                expect(m.gas.remaining).to(equal(819))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.stack.length).to(equal(0))
            }

            it("does not use refunds to pay for logs") {
                let m = TestMachine.machine(opcode: .LOG0, gasLimit: 374)
                m.gas.recordRefund(refund: 1000)
                Self.pushArguments(m, offset: .ZERO, size: .ZERO, n: 0)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect((m.handler as! TestHandler).logs).to(beEmpty())
                expect(m.gas.remaining).to(equal(374))
                expect(m.gas.refunded).to(equal(1000))
            }

            it("retains earlier substate logs until the caller applies commit, revert or discard") {
                for ending in [Opcode.STOP, .REVERT, .INVALID] {
                    let handler = StateHandler()
                    let previous = Log(address: TestHandler.address1, topics: [], data: [0xaa])
                    handler.state.log(address: previous.address, topics: previous.topics, data: previous.data)
                    handler.state.enter(gasLimit: 2000, isStatic: false)
                    let code: [UInt8] = [Opcode.LOG1.rawValue, Opcode.PUSH1.rawValue, 0, Opcode.PUSH1.rawValue, 0, ending.rawValue]
                    let m = Machine(data: [], code: code, gasLimit: 2000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                    Self.pushArguments(m, offset: .ZERO, size: .ZERO, n: 1)

                    m.evalLoop()

                    let emitted = Log(address: H160.ZERO, topics: [Self.topics[0]], data: [])
                    expect(handler.state.logs).to(equal([emitted]))
                    // Executor finalization is explicit in this integration test.
                    switch ending {
                    case .STOP:
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        handler.state.exitCommit()
                        expect(handler.state.logs).to(equal([previous, emitted]))
                    case .REVERT:
                        expect(m.machineStatus).to(equal(.Exit(.Revert)))
                        handler.state.exitRevert()
                        expect(handler.state.logs).to(equal([previous]))
                    default:
                        expect(m.machineStatus).to(equal(.Exit(.Error(.InvalidOpcode(ending.rawValue)))))
                        handler.state.exitDiscard()
                        expect(handler.state.logs).to(equal([previous]))
                    }
                }
            }

            it("discards successful descendant logs when their parent reverts") {
                let handler = StateHandler()
                let rootLog = Log(address: TestHandler.address1, topics: [], data: [0xaa])
                handler.state.log(address: rootLog.address, topics: rootLog.topics, data: rootLog.data)
                handler.state.enter(gasLimit: 3000, isStatic: false)
                handler.state.enter(gasLimit: 2000, isStatic: false)
                let m = Machine(data: [], code: [Opcode.LOG4.rawValue], gasLimit: 2000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                Self.pushArguments(m, offset: .ZERO, size: .ZERO, n: 4)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                let childLog = Log(address: H160.ZERO, topics: Self.topics, data: [])
                expect(handler.state.logs).to(equal([childLog]))
                handler.state.exitCommit()
                expect(handler.state.logs).to(equal([childLog]))
                handler.state.exitRevert()
                expect(handler.state.logs).to(equal([rootLog]))
            }

            it("inherits static mode through substates even when the child requests a mutable call") {
                let handler = StateHandler()
                handler.state.enter(gasLimit: 3000, isStatic: true)
                handler.state.enter(gasLimit: 2000, isStatic: false)
                let m = Machine(data: [], code: [Opcode.LOG0.rawValue], gasLimit: 2000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                Self.pushArguments(m, offset: .MAX, size: .ZERO, n: 0)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.WriteInStaticContext))))
                expect(handler.state.logs).to(beEmpty())
                handler.state.exitDiscard()
                handler.state.exitDiscard()
                expect(handler.state.logs).to(beEmpty())
            }

            #if TRACING
            it("traces LOG stack consumption and gas for every topic count") {
                for (n, opcode) in [Opcode.LOG0, .LOG1, .LOG2, .LOG3, .LOG4].enumerated() {
                    let m = TestMachine.machine(opcode: opcode, gasLimit: 3000)
                    m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                    Self.pushArguments(m, offset: .ZERO, size: U256(from: 1), n: n)
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.trace.beforeEval?.stack?.data).to(equal(original))
                    expect(m.trace.data.count).to(equal(1))
                    expect(m.trace.data.first?.opcode).to(equal(opcode))
                    expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99)]))
                    expect(m.trace.data.first?.tracedGas?.used).to(equal(UInt64(386 + 375 * n)))
                    expect(m.trace.data.first?.tracedGas?.remaining).to(equal(UInt64(2614 - 375 * n)))
                    #if TRACE_STACK_INOUT
                    expect(m.stack.traceStackOut).to(equal([U256.ZERO, U256(from: 1)] + Array(Self.topicWords.prefix(n))))
                    #endif
                }
            }
            #endif
        }
    }
}
