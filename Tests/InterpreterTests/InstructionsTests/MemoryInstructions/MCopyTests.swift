@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MCopySpec: QuickSpec {
    private static func pushArguments(_ m: Machine, size: U256, source: U256 = .ZERO, destination: U256 = .ZERO) {
        expect(m.stack.push(value: size)).to(beSuccess())
        expect(m.stack.push(value: source)).to(beSuccess())
        expect(m.stack.push(value: destination)).to(beSuccess())
    }

    override class func spec() {
        describe("Instruction MCOPY") {
            it("copies a snapshot of either overlapping range and expands source and destination from Cancun onward") {
                let forks = HardFork.allCases.drop(while: { $0 != .Cancun })
                expect(forks.first).to(equal(.Cancun))
                for fork in forks {
                    for source in [0, 1, 31, 32, 63, 96] {
                        for destination in [0, 1, 31, 32, 63, 96] {
                            for size in [0, 1, 8, 31, 32, 33, 65] {
                                let end = size == 0 ? 32 : max(32, max(source, destination) + size)
                                let words = (end + 31) / 32
                                let memoryCost = 3 * words + words * words / 512
                                let copyCost = 3 + 3 * ((size + 31) / 32)
                                let m = TestMachine.machine(opcodes: [.MCOPY], gasLimit: UInt64(memoryCost + copyCost), memoryLimit: words * 32, hardFork: fork)
                                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                                let initial = (1 ... 32).map { UInt8($0) }
                                expect(m.memory.set(offset: 0, value: initial, size: 32)).to(beSuccess())
                                let snapshot = initial + [UInt8](repeating: 0, count: words * 32 - 32)
                                var expected = snapshot
                                for i in 0 ..< size { expected[destination + i] = snapshot[source + i] }
                                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                                Self.pushArguments(m, size: U256(from: UInt64(size)), source: U256(from: UInt64(source)), destination: U256(from: UInt64(destination)))
                                let detail = "fork \(fork), source \(source), destination \(destination), size \(size)"

                                m.evalLoop()

                                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                                expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                                expect(m.gas.remaining).to(equal(0), description: detail)
                                expect(m.gas.memoryGas.gasCost).to(equal(UInt64(memoryCost)), description: detail)
                                expect(m.memory.effectiveLength).to(equal(words * 32), description: detail)
                                expect(m.memory.get(offset: 0, size: words * 32)).to(equal(expected), description: detail)
                                expect(m.pc).to(equal(1), description: detail)
                            }
                        }
                    }
                }
            }

            it("rejects every pre-Cancun fork before inspecting the stack or charging gas") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Cancun })
                expect(forks.last).to(equal(.Shanghai))
                for fork in forks {
                    for count in 0 ... 3 {
                        let m = TestMachine.machine(opcodes: [.MCOPY], gasLimit: 0, memoryLimit: 0, hardFork: fork)
                        for _ in 0 ..< count { expect(m.stack.push(value: .MAX)).to(beSuccess()) }
                        let original = m.stack.data

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                        expect(m.stack.data).to(equal(original))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.memory.effectiveLength).to(equal(0))
                        expect(m.pc).to(equal(0))
                    }
                }
            }

            it("rejects every stack underflow before charging gas") {
                for count in 0 ..< 3 {
                    for budget: UInt64 in [0, 100] {
                        let m = TestMachine.machine(opcode: .MCOPY, gasLimit: budget)
                        for _ in 0 ..< count { expect(m.stack.push(value: .MAX)).to(beSuccess()) }
                        let original = m.stack.data

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                        expect(m.stack.data).to(equal(original))
                        expect(m.gas.remaining).to(equal(budget))
                        expect(m.memory.effectiveLength).to(equal(0))
                        expect(m.pc).to(equal(0))
                    }
                }
            }

            it("ignores both full-width offsets for an empty copy but still charges three gas") {
                for source in [U256.ZERO, U256(from: UInt64(Int.max)), U256.MAX] {
                    for destination in [U256.ZERO, U256(from: UInt64(Int.max)), U256.MAX] {
                        for budget: UInt64 in [2, 3] {
                            let m = TestMachine.machine(opcodes: [.MCOPY], gasLimit: budget, memoryLimit: 0)
                            Self.pushArguments(m, size: .ZERO, source: source, destination: destination)
                            let original = m.stack.data

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(budget == 3 ? .Exit(.Success(.Stop)) : .Exit(.Error(.OutOfGas))))
                            expect(m.stack.data).to(equal(budget == 3 ? [] : original))
                            expect(m.gas.remaining).to(equal(budget == 3 ? 0 : 2))
                            expect(m.gas.memoryGas.numWords).to(equal(0))
                            expect(m.memory.effectiveLength).to(equal(0))
                        }
                    }
                }
            }

            it("charges quadratic expansion for an identical range and does not charge it again") {
                let m = TestMachine.machine(opcodes: [.MCOPY, .MCOPY, .MSIZE], gasLimit: 84, memoryLimit: 736)
                Self.pushArguments(m, size: U256(from: 1), source: U256(from: 704), destination: U256(from: 704))

                m.step()

                expect(m.machineStatus).to(equal(.Continue))
                expect(m.gas.remaining).to(equal(8))
                expect(m.gas.memoryGas.numWords).to(equal(23))
                expect(m.gas.memoryGas.gasCost).to(equal(70))
                expect(m.memory.effectiveLength).to(equal(736))
                expect(m.memory.get(offset: 0, size: 736)).to(equal([UInt8](repeating: 0, count: 736)))
                Self.pushArguments(m, size: U256(from: 1), source: U256(from: 704))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(70))
                expect(m.stack.data).to(equal([U256(from: 736)]))
            }

            it("preserves memory and operands when copy or expansion gas cannot be paid") {
                for (budget, remaining, words): (UInt64, UInt64, Int) in [(8, 5, 1), (11, 2, 2)] {
                    let m = TestMachine.machine(opcode: .MCOPY, gasLimit: budget)
                    expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                    expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                    Self.pushArguments(m, size: U256(from: 1), destination: U256(from: 32))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(remaining))
                    expect(m.gas.memoryGas.numWords).to(equal(words))
                    expect(m.memory.effectiveLength).to(equal(32))
                    expect(m.memory.get(offset: 0, size: 32)).to(equal([0xab] + [UInt8](repeating: 0, count: 31)))
                    expect(m.pc).to(equal(0))
                    m.evalLoop()
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(remaining))
                }
            }

            it("rejects unrepresentable operands and overflowing source or destination ranges") {
                let one = U256(from: 1)
                let cases: [(U256, U256, U256, UInt64)] = [
                    (.MAX, .ZERO, .ZERO, 100), (U256(from: UInt64(Int.max) + 1), .ZERO, .ZERO, 100),
                    (one, .MAX, .ZERO, 100), (one, .ZERO, .MAX, 100),
                    (one, U256(from: [1, 1, 0, 0]), .ZERO, 100), (one, .ZERO, U256(from: [1, 0, 1, 0]), 100),
                    (one, U256(from: UInt64(Int.max)), .ZERO, 94), (one, .ZERO, U256(from: UInt64(Int.max)), 94)
                ]
                for (size, source, destination, remaining) in cases {
                    let m = TestMachine.machine(opcode: .MCOPY, gasLimit: 100)
                    Self.pushArguments(m, size: size, source: source, destination: destination)
                    let original = m.stack.data
                    let detail = "size \(size), source \(source), destination \(destination)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                    expect(m.stack.data).to(equal(original), description: detail)
                    expect(m.gas.remaining).to(equal(remaining), description: detail)
                    expect(m.memory.effectiveLength).to(equal(0), description: detail)
                    expect(m.pc).to(equal(0), description: detail)
                }
            }

            it("rejects overflowing memory gas before allocation") {
                let m = TestMachine.machine(opcode: .MCOPY, gasLimit: UInt64.max)
                Self.pushArguments(m, size: U256(from: UInt64(Int.max)))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(UInt64.max - 3 - 3 * (UInt64(Int.max) / 32 + 1)))
                expect(m.stack.length).to(equal(3))
                expect(m.memory.effectiveLength).to(equal(0))
            }

            it("enforces the rounded memory limit for both ranges, including an identical range") {
                for (source, destination): (UInt64, UInt64) in [(32, 0), (0, 32), (32, 32)] {
                    for limit in [32, 63] {
                        let m = TestMachine.machine(opcodes: [.MCOPY], gasLimit: 12, memoryLimit: limit)
                        Self.pushArguments(m, size: U256(from: 1), source: U256(from: source), destination: U256(from: destination))
                        let original = m.stack.data

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.stack.data).to(equal(original))
                        expect(m.memory.effectiveLength).to(equal(0))
                    }
                }
            }

            it("is allowed in a static call and consumes only three operands on a full stack") {
                let handler = StaticHandler()
                let m = Machine(data: [], code: [Opcode.MCOPY.rawValue], gasLimit: 12, memoryLimit: 64,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Cancun)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                for _ in 0 ..< m.stack.limit - 3 { expect(m.stack.push(value: U256(from: 99))).to(beSuccess()) }
                let original = m.stack.data
                Self.pushArguments(m, size: U256(from: 1), destination: U256(from: 32))
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 32, size: 1)).to(equal([0xab]))
                expect(m.stack.data).to(equal(original))
                expect(m.gas.remaining).to(equal(0))
            }

            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            it("reports allocation failure before consuming operands or copying bytes") {
                for initialized in [false, true] {
                    let memory = FailingAllocationMemory()
                    let m = Machine(data: [], code: [Opcode.MCOPY.rawValue], gasLimit: 12,
                                    context: TestMachine.defaultContext(), state: ExecutionState(), handler: TestHandler(), memory: memory)
                    if initialized {
                        expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                        expect(memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                    }
                    let originalMemory = memory.get(offset: 0, size: memory.effectiveLength)
                    memory.failAllocations = true
                    Self.pushArguments(m, size: U256(from: 1), destination: U256(from: 32))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Fatal(.ReadMemory))))
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.stack.data).to(equal(original))
                    expect(memory.effectiveLength).to(equal(initialized ? 32 : 0))
                    expect(memory.get(offset: 0, size: memory.effectiveLength)).to(equal(originalMemory))
                }
            }
            #endif

            #if TRACING
            it("traces destination, source, length and both gas charges") {
                let m = TestMachine.machine(opcode: .MCOPY, gasLimit: 12)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab, 0xcd, 0xef], size: 3)).to(beSuccess())
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                Self.pushArguments(m, size: U256(from: 1), source: U256(from: 2), destination: U256(from: 32))
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 32, size: 1)).to(equal([0xef]))
                expect(m.trace.beforeEval?.stack?.data).to(equal(original))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.MCOPY))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(9))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(0))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([U256(from: 32), U256(from: 2), U256(from: 1)]))
                expect(m.trace.data.first?.stackIn).to(beEmpty())
                #endif
            }
            #endif
        }
    }
}
