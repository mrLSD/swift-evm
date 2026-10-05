@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMachineTestsSpec: QuickSpec {
    class CountingHandler: TestHandler {
        var calls = 0

        override func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
            calls += 1
            return nil
        }
    }

    class CustomHandler: TestHandler {
        var observedStatuses: [Machine.MachineStatus] = []

        override func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
            observedStatuses.append(machine.machineStatus)
            return .OutOfFund
        }
    }

    override class func spec() {
        describe("Machine tests") {
            context("completed execution") {
                it("preserves fatal exits without invoking the handler") {
                    let handler = CountingHandler()
                    let m = Machine(data: [], code: [Opcode.PC.rawValue], gasLimit: 100, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                    m.machineStatus = .Exit(.Fatal(.ReadMemory))
                    m.step()
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Fatal(.ReadMemory))))
                    expect(m.pc).to(equal(0))
                    expect(m.gas.remaining).to(equal(100))
                    expect(m.stack.length).to(equal(0))
                    expect(handler.calls).to(equal(0))
                }

                it("preserves every exit and all observable state on repeated step and evalLoop calls") {
                    let cases: [(code: [UInt8], gas: UInt64, stack: [UInt64], status: Machine.MachineStatus)] = [
                        ([], 100, [], .Exit(.Success(.Stop))),
                        ([0x00], 100, [], .Exit(.Success(.Stop))),
                        ([0xF3], 100, [3, 0], .Exit(.Success(.Return))),
                        ([0xFD], 100, [3, 0], .Exit(.Revert)),
                        ([0x0C], 100, [], .Exit(.Error(.InvalidOpcode(0x0C)))),
                        ([0x01], 100, [], .Exit(.Error(.StackUnderflow))),
                        ([0x58], 1, [], .Exit(.Error(.OutOfGas))),
                        ([0x56], 100, [1], .Exit(.Error(.InvalidJump))),
                        ([0x39], 10_000_000, [1, 0, 1_048_576], .Exit(.Error(.OutOfGas))),
                        ([0x37], 10_000_000, [1, 0, 1_048_576], .Exit(.Error(.OutOfGas))),
                    ]
                    for testCase in cases {
                        let handler = CountingHandler()
                        let m = Machine(data: [0xAB], code: testCase.code, gasLimit: testCase.gas, memoryLimit: 32, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Prague)
                        if testCase.code == [0xF3] || testCase.code == [0xFD] {
                            expect(m.memory.set(offset: 0, value: [0xAB, 0xCD, 0xEF], size: 3)).to(beSuccess())
                        }
                        for value in testCase.stack { m.stackPush(value: U256(from: value)) }
                        m.evalLoop()
                        expect(m.machineStatus).to(equal(testCase.status), description: "code=\(testCase.code)")
                        let pc = m.pc
                        let gas = m.gas
                        let stack = m.stack.data
                        let length = m.memory.effectiveLength
                        let bytes = m.memory.get(offset: 0, size: length)
                        let returnRange = m.returnRange
                        let calls = handler.calls
                        #if TRACING
                        let traceCount = m.trace.data.count
                        #endif

                        for _ in 0 ..< 2 {
                            m.step()
                            m.evalLoop()
                            expect(m.machineStatus).to(equal(testCase.status))
                            expect(m.pc).to(equal(pc))
                            expect(m.gas).to(equal(gas))
                            expect(m.stack.data).to(equal(stack))
                            expect(m.memory.effectiveLength).to(equal(length))
                            expect(m.memory.get(offset: 0, size: length)).to(equal(bytes))
                            expect(m.returnRange).to(equal(returnRange))
                            expect(handler.calls).to(equal(calls))
                            #if TRACING
                            expect(m.trace.data.count).to(equal(traceCount))
                            #endif
                        }
                    }
                }

                it("continues after a manual step without restarting or skipping instructions") {
                    let m = TestMachine.machine(opcodes: [.PC, .PC, .STOP], gasLimit: 10)
                    m.step()
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([.ZERO, U256(from: 1)]))
                    expect(m.gas.remaining).to(equal(6))
                    expect(m.pc).to(equal(2))
                }
            }

            context("memory limits at opcode boundaries") {
                it("rejects every memory access whose rounded capacity exceeds the limit") {
                    let opcodes: [Opcode] = [.MLOAD, .MSTORE, .MSTORE8, .SHA3, .RETURN, .REVERT, .LOG0, .LOG4, .CODECOPY, .CALLDATACOPY]
                    for opcode in opcodes {
                        for limit in [0, 1, 31, 32, 33, 63] {
                            let m = TestMachine.machine(opcodes: [opcode], gasLimit: 10_000_000, memoryLimit: limit)
                            if opcode == .LOG4 {
                                for topic in 1 ... 4 { m.stackPush(value: U256(from: UInt64(topic))) }
                            }
                            if opcode != .MLOAD { m.stackPush(value: U256(from: 1)) }
                            if opcode == .CODECOPY || opcode == .CALLDATACOPY { m.stackPush(value: .ZERO) }
                            m.stackPush(value: U256(from: UInt64(limit / 32 * 32)))
                            m.evalLoop()
                            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: "opcode=\(opcode), limit=\(limit)")
                            expect(m.memory.effectiveLength).to(equal(0))
                        }
                    }
                }

                it("permits the final allocated byte and rejects the next rounded word without changing it") {
                    let handler = CountingHandler()
                    let code: [UInt8] = [0x60, 0xAA, 0x60, 31, 0x53, 0x60, 0xBB, 0x60, 32, 0x53]
                    let m = Machine(data: [], code: code, gasLimit: 100, memoryLimit: 33, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Prague)
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.memory.effectiveLength).to(equal(32))
                    expect(m.memory.get(offset: 31, size: 2)).to(equal([0xAA, 0]))
                }

                it("ignores offsets and allocates nothing for empty ranges even with a zero limit") {
                    for opcode in [Opcode.SHA3, .RETURN, .REVERT, .LOG0, .CODECOPY, .CALLDATACOPY] {
                        let m = TestMachine.machine(opcodes: [opcode], gasLimit: 1000, memoryLimit: 0)
                        m.stackPush(value: .ZERO)
                        if opcode == .CODECOPY || opcode == .CALLDATACOPY { m.stackPush(value: .MAX) }
                        m.stackPush(value: .MAX)
                        m.evalLoop()
                        let expected: Machine.MachineStatus = opcode == .RETURN ? .Exit(.Success(.Return)) : opcode == .REVERT ? .Exit(.Revert) : .Exit(.Success(.Stop))
                        expect(m.machineStatus).to(equal(expected), description: "opcode=\(opcode)")
                        expect(m.memory.effectiveLength).to(equal(0))
                        expect(m.gas.memoryGas.numWords).to(equal(0))
                    }
                }
            }

            #if TRACING
            context("instruction tracing") {
                #if Tracing
                it("maps package traits to the default trace configuration") {
                    let config = Trace.Config()
                    #if TraceCallTrace
                    expect(config.callTrace).to(beTrue())
                    #else
                    expect(config.callTrace).to(beFalse())
                    #endif
                    #if TraceGasCalculation
                    expect(config.gasCalculation).to(beTrue())
                    #else
                    expect(config.gasCalculation).to(beFalse())
                    #endif
                    #if TraceStackInOut
                    expect(config.stackInOut).to(beTrue())
                    #else
                    expect(config.stackInOut).to(beFalse())
                    #endif
                    #if TraceHideUnchanged
                    expect(config.hideUnchanged).to(beTrue())
                    #else
                    expect(config.hideUnchanged).to(beFalse())
                    #endif
                    #if TraceHideMemory
                    expect(config.hideMemory).to(beTrue())
                    #else
                    expect(config.hideMemory).to(beFalse())
                    #endif
                    #if TraceHideStack
                    expect(config.hideStack).to(beTrue())
                    #else
                    expect(config.hideStack).to(beFalse())
                    #endif
                    #if TraceHideStorage
                    expect(config.hideStorage).to(beTrue())
                    #else
                    expect(config.hideStorage).to(beFalse())
                    #endif
                    #if TraceStorageHexValue
                    expect(config.storageValueAsHex).to(beTrue())
                    #else
                    expect(config.storageValueAsHex).to(beFalse())
                    #endif
                    #if TraceOpcodeHexValue
                    expect(config.opcodeAsHex).to(beTrue())
                    #else
                    expect(config.opcodeAsHex).to(beFalse())
                    #endif
                }
                #endif

                func config(hidden: Bool, stackInOut: Bool) -> Trace.Config {
                    Trace.Config(callTrace: false, gasCalculation: true, stackInOut: stackInOut, hideUnchanged: false, hideMemory: hidden, hideStack: hidden, hideStorage: true, storageValueAsHex: false, opcodeAsHex: true)
                }

                it("records historical memory, the executed PC, gas and per-instruction stack changes") {
                    let m = TestMachine.machine(rawCode: [0x60, 0xAA, 0x60, 0, 0x53, 0x60, 0xBB, 0x60, 0, 0x53, 0], gasLimit: 100)
                    let trace = Trace(config: config(hidden: false, stackInOut: true), context: .init(address: .ZERO))
                    m.trace = trace
                    m.evalLoop()
                    expect(trace.data.map(\.pc)).to(equal([0, 2, 4, 5, 7, 9, 10]))
                    expect(trace.data.map(\.opcode)).to(equal([.PUSH1, .PUSH1, .MSTORE8, .PUSH1, .PUSH1, .MSTORE8, .STOP]))
                    expect(trace.data[0].memory).to(equal([]))
                    expect(trace.data[2].memory).to(equal([0xAA] + [UInt8](repeating: 0, count: 31)))
                    expect(trace.data[5].memory).to(equal([0xBB] + [UInt8](repeating: 0, count: 31)))
                    expect(trace.data[2].stack?.data).to(equal([]))
                    expect(trace.data[0].tracedGas?.used).to(equal(3))
                    expect(trace.data[2].tracedGas?.used).to(equal(6))
                    expect(trace.data.last?.tracedGas?.remaining).to(equal(79))
                    expect(trace.data.last?.tracedGas?.totalSpent).to(equal(21))
                    expect(trace.data.last?.tracedGas?.refunded).to(equal(0))
                    #if TRACE_STACK_INOUT
                    expect(trace.data[0].stackIn).to(equal([U256(from: 0xAA)]))
                    expect(trace.data[2].stackOut).to(equal([.ZERO, U256(from: 0xAA)]))
                    expect(trace.data[3].stackIn).to(equal([U256(from: 0xBB)]))
                    expect(trace.data.last?.stackIn).to(equal([]))
                    expect(m.stack.traceStackIn).to(beEmpty())
                    expect(m.stack.traceStackOut).to(beEmpty())
                    #else
                    expect(trace.data[0].stackIn).to(beNil())
                    expect(trace.data[2].stackOut).to(beNil())
                    #endif

                    let executed = TestMachine.machine(rawCode: m.code, gasLimit: 100)
                    executed.evalLoop()
                    expect(executed.trace.data.map(\.pc)).to(equal(trace.data.map(\.pc)))
                    #if TRACE_STACK_INOUT
                    expect(executed.stack.traceStackIn).to(beEmpty())
                    expect(executed.stack.traceStackOut).to(beEmpty())
                    #endif
                }

                it("honors explicit hiding and stack journal settings") {
                    let m = TestMachine.machine(opcode: .STOP, gasLimit: 10)
                    expect(m.memory.set(offset: 0, value: [0xAB], size: 1)).to(beSuccess())
                    m.stackPush(value: U256(from: 7))
                    _ = m.stackPop()
                    for hidden in [false, true] {
                        for stackInOut in [false, true] {
                            let trace = Trace(config: config(hidden: hidden, stackInOut: stackInOut), context: .init(address: TestHandler.address1))
                            trace.beforeEval(m, .STOP)
                            trace.afterEval(m).complete()
                            let entry = trace.data[0]
                            expect(trace.context?.address).to(equal(TestHandler.address1))
                            expect(entry.memory == nil).to(equal(hidden))
                            expect(entry.stack == nil).to(equal(hidden))
                            #if TRACE_STACK_INOUT
                            if stackInOut {
                                expect(entry.stackIn).to(equal([U256(from: 7)]))
                                expect(entry.stackOut).to(equal([U256(from: 7)]))
                            } else {
                                expect(entry.stackIn).to(beNil())
                                expect(entry.stackOut).to(beNil())
                            }
                            #else
                            expect(entry.stackIn).to(beNil())
                            expect(entry.stackOut).to(beNil())
                            #endif
                        }
                    }
                }

                it("does not append incomplete steps and renders both small and full-width stack values") {
                    let m = TestMachine.machine(opcode: .STOP, gasLimit: 10)
                    let trace = Trace(config: config(hidden: false, stackInOut: false), context: .init(address: .ZERO))
                    trace.afterEval(m).complete()
                    expect(trace.data).to(beEmpty())
                    trace.beforeEval(m, .STOP)
                    trace.complete()
                    expect(trace.data).to(beEmpty())
                    m.stackPush(value: U256(from: 15))
                    m.stackPush(value: .MAX)
                    trace.afterEval(m).complete()
                    let hidden = Trace.TraceData(m, .STOP, config(hidden: true, stackInOut: false), pc: 0)
                    trace.data.append(hidden)
                    let output = captureStandardOutput { trace.printOutput() }
                    expect(output).to(contain("PC: 0", "STOP", "Gas { remaining: 10, refunded: 0, used: 0, totalSpent: 0 }", "[f, 0x", "Stack: []"))
                    let hiddenTrace = Trace(config: config(hidden: true, stackInOut: false), context: .init(address: .ZERO))
                    hiddenTrace.data.append(hidden)
                    expect(captureStandardOutput { hiddenTrace.printOutput() }).toNot(contain("Stack:"))
                    trace.beforeEval(m, .STOP)
                    trace.complete()
                    expect(trace.data.count).to(equal(2))
                    trace.afterEval(m).complete()
                    expect(trace.data.count).to(equal(3))
                }
            }
            #endif

            context("Starting execution with step") {
                it("executes consecutive instructions once and matches evalLoop") {
                    let m = TestMachine.machine(opcodes: [.PC, .PC, .STOP], gasLimit: 10)
                    expect(m.machineStatus).to(equal(.NotStarted))

                    m.step()

                    expect(m.machineStatus).to(equal(.Continue))
                    expect(m.pc).to(equal(1))
                    expect(m.stack.data).to(equal([U256.ZERO]))
                    expect(m.gas.remaining).to(equal(8))

                    m.step()

                    expect(m.machineStatus).to(equal(.Continue))
                    expect(m.pc).to(equal(2))
                    expect(m.stack.data).to(equal([U256.ZERO, U256(from: 1)]))
                    expect(m.gas.remaining).to(equal(6))

                    m.step()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.pc).to(equal(2))
                    expect(m.stack.data).to(equal([U256.ZERO, U256(from: 1)]))
                    expect(m.gas.remaining).to(equal(6))

                    let looped = TestMachine.machine(opcodes: [.PC, .PC, .STOP], gasLimit: 10)
                    looped.evalLoop()
                    expect(m.machineStatus).to(equal(looped.machineStatus))
                    expect(m.pc).to(equal(looped.pc))
                    expect(m.stack.data).to(equal(looped.stack.data))
                    expect(m.gas.remaining).to(equal(looped.gas.remaining))
                }

                it("preserves immediate exits and specific errors on the first step") {
                    let cases: [(code: [UInt8], gas: UInt64, status: Machine.MachineStatus)] = [
                        ([], 0, .Exit(.Success(.Stop))),
                        ([Opcode.STOP.rawValue], 0, .Exit(.Success(.Stop))),
                        ([0x0C], 10, .Exit(.Error(.InvalidOpcode(0x0C)))),
                        ([Opcode.ADD.rawValue], 10, .Exit(.Error(.StackUnderflow))),
                        ([Opcode.PC.rawValue], 1, .Exit(.Error(.OutOfGas))),
                    ]
                    for testCase in cases {
                        let m = TestMachine.machine(rawCode: testCase.code, gasLimit: testCase.gas)

                        m.step()

                        expect(m.machineStatus).to(equal(testCase.status), description: "code=\(testCase.code)")
                        expect(m.pc).to(equal(0))
                        expect(m.stack.length).to(equal(0))
                        expect(m.gas.remaining).to(equal(testCase.gas))
                    }
                }

                it("starts before invoking the handler and preserves its error") {
                    let handler = CustomHandler()
                    let m = Machine(data: [], code: [Opcode.PC.rawValue], gasLimit: 10, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)

                    m.step()

                    expect(handler.observedStatuses).to(equal([.Continue]))
                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
                    expect(m.pc).to(equal(0))
                    expect(m.stack.length).to(equal(0))
                    expect(m.gas.remaining).to(equal(10))
                }

                it("preserves instruction-controlled advancement on the first step") {
                    let pushed = TestMachine.machine(rawCode: [Opcode.PUSH1.rawValue, 0xAB], gasLimit: 10)
                    pushed.step()
                    expect(pushed.machineStatus).to(equal(.Continue))
                    expect(pushed.pc).to(equal(2))
                    expect(pushed.stack.data).to(equal([U256(from: 0xAB)]))
                    expect(pushed.gas.remaining).to(equal(7))

                    let jumped = TestMachine.machine(opcodes: [.JUMP, .JUMPDEST], gasLimit: 10)
                    jumped.stackPush(value: U256(from: 1))
                    jumped.step()
                    expect(jumped.machineStatus).to(equal(.Continue))
                    expect(jumped.pc).to(equal(1))
                    expect(jumped.stack.length).to(equal(0))
                    expect(jumped.gas.remaining).to(equal(2))
                }
            }

            it("classifies oversized memory operands as OutOfGas across opcodes") {
                let bounds: [U256] = [
                    U256(from: UInt64(Int.max)), U256(from: UInt64(Int.max) + 1),
                    U256(from: [0, 1, 0, 0]), U256(from: [0, 0, 1, 0]),
                    U256(from: [0, 0, 0, 1]), U256(from: [0, 0, 0, 1 << 63]), .MAX,
                ]
                let opcodes: [Opcode] = [.MLOAD, .MSTORE, .MSTORE8, .CODECOPY, .CALLDATACOPY, .SHA3, .RETURN, .REVERT, .LOG0, .LOG4]
                for opcode in opcodes {
                    for bound in bounds {
                        let m = TestMachine.machine(opcode: opcode, gasLimit: 10000)
                        if opcode == .LOG4 {
                            for topic in 1 ... 4 {
                                m.stackPush(value: U256(from: UInt64(topic)))
                            }
                        }
                        if opcode != .MLOAD {
                            m.stackPush(value: U256(from: 1))
                        }
                        if opcode == .CODECOPY || opcode == .CALLDATACOPY {
                            m.stackPush(value: .ZERO)
                        }
                        m.stackPush(value: bound)
                        m.evalLoop()
                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: "opcode=\(opcode), offset=\(bound)")
                        expect(m.memory.effectiveLength).to(equal(0))
                    }
                }

                for opcode in [Opcode.CODECOPY, .CALLDATACOPY, .SHA3, .RETURN, .REVERT, .LOG0] {
                    for bound in bounds {
                        let m = TestMachine.machine(opcode: opcode, gasLimit: 10000)
                        m.stackPush(value: bound)
                        if opcode == .CODECOPY || opcode == .CALLDATACOPY {
                            m.stackPush(value: .ZERO)
                        }
                        m.stackPush(value: .ZERO)
                        m.evalLoop()
                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: "opcode=\(opcode), size=\(bound)")
                        expect(m.memory.effectiveLength).to(equal(0))
                    }
                }
            }

            it("zero-fills copies from oversized source offsets") {
                for opcode in [Opcode.CODECOPY, .CALLDATACOPY] {
                    let m = TestMachine.machine(data: [0xAB], opcode: opcode, gasLimit: 100)
                    m.stackPush(value: U256(from: 1))
                    m.stackPush(value: .MAX)
                    m.stackPush(value: U256(from: 32))
                    m.evalLoop()
                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.memory.get(offset: 32, size: 1)).to(equal([0]))
                    expect(m.gas.remaining).to(equal(88))
                }
            }

            it("rejects huge jump destinations only when the jump is taken") {
                let targets: [U256] = [U256(from: UInt64(Int.max)), U256(from: UInt64(Int.max) + 1), U256(from: [0, 1, 0, 0]), U256(from: [0, 0, 1, 0]), U256(from: [0, 0, 0, 1]), .MAX]
                for target in targets {
                    for opcode in [Opcode.JUMP, .JUMPI] {
                        for condition in [U256.ZERO, U256(from: 1)] {
                            let m = TestMachine.machine(opcode: opcode, gasLimit: 10)
                            if opcode == .JUMPI {
                                m.stackPush(value: condition)
                            }
                            m.stackPush(value: target)

                            m.evalLoop()

                            let expected: Machine.MachineStatus = opcode == .JUMPI && condition.isZero
                                ? .Exit(.Success(.Stop)) : .Exit(.Error(.InvalidJump))
                            expect(m.machineStatus).to(equal(expected), description: "opcode=\(opcode), target=\(target), condition=\(condition)")
                            expect(m.gas.remaining).to(equal(opcode == .JUMP ? 2 : 0))
                            expect(m.stack.length).to(equal(0))
                        }
                    }
                }
            }

            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            it("stops MSTORE with OutOfGas on allocation failure after charging memory gas") {
                for initialized in [false, true] {
                    let memory = FailingAllocationMemory()
                    if initialized {
                        expect(memory.set(offset: 0, value: [0xAB], size: 1)).to(beSuccess())
                    }
                    memory.failAllocations = true
                    let m = Machine(
                        data: [], code: [Opcode.MSTORE.rawValue], gasLimit: 100,
                        context: TestMachine.defaultContext(), state: ExecutionState(), handler: TestHandler(), memory: memory
                    )
                    m.stackPush(value: U256(from: 0xCD))
                    m.stackPush(value: U256(from: 32))
                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.gas.remaining).to(equal(91))
                    expect(m.gas.memoryGas.numWords).to(equal(2))
                    expect(m.memory.effectiveLength).to(equal(initialized ? 32 : 0))
                    expect(m.memory.get(offset: 0, size: 1)).to(equal([initialized ? 0xAB : 0]))
                    expect(m.stack.length).to(equal(0))
                }
            }
            #endif

            it("memory integer conversion reports OutOfGas") {
                for value in [0, 1, Int.max] {
                    let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                    let result = m.getMemoryIntOrFail(U256(from: UInt64(value)))

                    expect(result).to(equal(value))
                    expect(m.machineStatus).to(equal(.NotStarted))
                    expect(m.gas.remaining).to(equal(1))
                }

                for value in [U256(from: UInt64(Int.max) + 1), U256(from: [1, 1, 0, 0]), .MAX] {
                    let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                    let result = m.getMemoryIntOrFail(value)

                    expect(result).to(beNil())
                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.gas.remaining).to(equal(1))
                }
            }

            it("Machine beforeOpcodeExecution flow") {
                let m = Machine(data: [], code: [Opcode.PC.rawValue], gasLimit: 100, context: TestMachine.defaultContext(), state: ExecutionState(), handler: CustomHandler())
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfFund))))
            }

            it("stackPop failure with StackUnderflow") {
                let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res = m.stackPop()
                expect(res).to(beNil())
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("stackPopH256 failure with StackUnderflow") {
                let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res = m.stackPopH256()
                expect(res).to(beNil())
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("stackPeek failure with StackUnderflow") {
                let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res = m.stackPeek(indexFromTop: 0)
                expect(res).to(beNil())
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
            }

            it("stackPeek failure with StackUnderflow") {
                let m = TestMachine.machine(opcodes: [], gasLimit: 1)
                for _ in 0 ..< 1024 {
                    m.stackPush(value: U256(from: 1))
                    expect(m.machineStatus).to(equal(.NotStarted))
                    expect(m.machineStatus).to(equal(.NotStarted))
                }
                m.stackPush(value: U256(from: 1))
                expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
            }

            it("resizeMemoryAndRecordGas early-returns true for size == 0") {
                // Per Yellow Paper §H.1: when length == 0, no memory access occurs and no
                // expansion is required, regardless of the offset. The early return prevents
                // spurious gas charges and avoids reaching `Memory.resize(_, 0)` which would
                // otherwise short-circuit and incorrectly trigger an OutOfGas exit.
                // Offset = 1024 would expand memory to 32 words and charge gas;
                // with size = 0 it must remain a no-op.
                let m = TestMachine.machine(opcodes: [], gasLimit: 100)
                let res = m.resizeMemoryAndRecordGas(offset: 1024, size: 0)

                expect(res).to(beTrue())
                expect(m.machineStatus).to(equal(.NotStarted))
                expect(m.gas.remaining).to(equal(100))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(0))
            }
        }
    }
}
