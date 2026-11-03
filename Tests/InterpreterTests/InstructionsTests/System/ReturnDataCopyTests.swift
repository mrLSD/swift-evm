@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionReturnDataCopySpec: QuickSpec {
    private static func pushArguments(_ m: Machine, size: U256, dataOffset: U256 = .ZERO, memoryOffset: U256 = .ZERO) {
        expect(m.stack.push(value: size)).to(beSuccess())
        expect(m.stack.push(value: dataOffset)).to(beSuccess())
        expect(m.stack.push(value: memoryOffset)).to(beSuccess())
    }

    override class func spec() {
        describe("Instruction RETURNDATACOPY") {
            it("copies exact bytes and charges copy and memory gas from Byzantium onward") {
                let buffer = (0 ..< 128).map { UInt8($0) }
                let forks = HardFork.allCases.drop(while: { $0 != .Byzantium })
                expect(forks.first).to(equal(.Byzantium))
                for fork in forks {
                    for size in [1, 31, 32, 33, 65] {
                        for destination in [0, 1, 31, 32] {
                            let words = (destination + size + 31) / 32
                            let cost = 3 + 3 * ((size + 31) / 32) + 3 * words + words * words / 512
                            let m = TestMachine.machine(opcodes: [.RETURNDATACOPY], gasLimit: UInt64(cost), memoryLimit: words * 32, hardFork: fork)
                            m.returnData = Machine.ReturnData(buffer: buffer, length: 2, offset: 90)
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            Self.pushArguments(m, size: U256(from: UInt64(size)), dataOffset: U256(from: 3), memoryOffset: U256(from: UInt64(destination)))
                            var expected = [UInt8](repeating: 0, count: words * 32)
                            for i in 0 ..< size { expected[destination + i] = UInt8(i + 3) }
                            let detail = "fork \(fork), size \(size), destination \(destination)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(m.gas.memoryGas.numWords).to(equal(words), description: detail)
                            expect(m.memory.effectiveLength).to(equal(words * 32), description: detail)
                            expect(m.memory.get(offset: 0, size: words * 32)).to(equal(expected), description: detail)
                            expect(m.returnData.buffer).to(equal(buffer), description: detail)
                            expect(m.returnData.length).to(equal(2), description: detail)
                            expect(m.returnData.offset).to(equal(90), description: detail)
                            expect(m.pc).to(equal(1), description: detail)
                        }
                    }
                }
            }

            it("rejects every pre-Byzantium fork before inspecting operands or charging gas") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Byzantium })
                expect(forks.last).to(equal(.SpuriousDragon))
                for fork in forks {
                    for count in 0 ... 3 {
                        let m = TestMachine.machine(opcodes: [.RETURNDATACOPY], gasLimit: 0, memoryLimit: 0, hardFork: fork)
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

            it("rejects all stack underflows before charging gas") {
                for count in 0 ..< 3 {
                    for budget: UInt64 in [0, 100] {
                        let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: budget)
                        for _ in 0 ..< count { expect(m.stack.push(value: .ZERO)).to(beSuccess()) }
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

            it("allows empty copies through the end of the buffer and ignores the destination") {
                for count in [0, 3] {
                    for source in 0 ... count {
                        for destination in [U256.ZERO, U256(from: UInt64(Int.max)), U256.MAX] {
                            let m = TestMachine.machine(opcodes: [.RETURNDATACOPY], gasLimit: 3, memoryLimit: 0)
                            let buffer = [UInt8](repeating: 0xab, count: count)
                            m.returnData = Machine.ReturnData(buffer: buffer, length: 1, offset: 7)
                            Self.pushArguments(m, size: .ZERO, dataOffset: U256(from: UInt64(source)), memoryOffset: destination)

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                            expect(m.stack.data).to(beEmpty())
                            expect(m.gas.remaining).to(equal(0))
                            expect(m.gas.memoryGas.numWords).to(equal(0))
                            expect(m.memory.effectiveLength).to(equal(0))
                            expect(m.returnData.buffer).to(equal(buffer))
                        }
                    }
                }
            }

            it("rejects out-of-bounds sources including empty reads and overflowing 256-bit sums") {
                let cases: [(U256, UInt64)] = [
                    (U256(from: 6), 0), (U256(from: 5), 1), (U256(from: 4), 2),
                    (U256(from: 0), 6), (U256(from: UInt64(Int.max)), 0),
                    (U256(from: UInt64(Int.max) + 1), 0),
                    (U256(from: [0, 1, 0, 0]), 0), (U256(from: [1, 0, 1, 0]), 1),
                    (.MAX, 0), (.MAX, 1)
                ]
                for (source, size) in cases {
                    let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 100)
                    let buffer: [UInt8] = [1, 0, 2, 0, 3]
                    m.returnData = Machine.ReturnData(buffer: buffer, length: 100, offset: 0)
                    expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                    expect(m.memory.set(offset: 0, value: [UInt8](repeating: 0xee, count: 32), size: 32)).to(beSuccess())
                    let memory = m.memory.get(offset: 0, size: 32)
                    Self.pushArguments(m, size: U256(from: size), dataOffset: source)
                    let original = m.stack.data
                    let detail = "source \(source), size \(size)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfOffset))), description: detail)
                    expect(m.stack.data).to(equal(original), description: detail)
                    expect(m.gas.remaining).to(equal(size == 0 ? 94 : 91), description: detail)
                    expect(m.memory.get(offset: 0, size: 32)).to(equal(memory), description: detail)
                    expect(m.returnData.buffer).to(equal(buffer), description: detail)
                    expect(m.pc).to(equal(0), description: detail)
                }
            }

            it("rejects a nonempty read from a fresh buffer after charging and expanding memory") {
                let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 9)
                Self.pushArguments(m, size: U256(from: 1))
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfOffset))))
                expect(m.stack.data).to(equal(original))
                expect(m.gas.remaining).to(equal(0))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 0, count: 32)))
                expect(m.returnData.buffer).to(beEmpty())
            }

            it("copies through the exact end without modifying surrounding bytes or frame output") {
                let m = TestMachine.machine(data: [0xff], opcodes: [.RETURNDATACOPY, .RETURNDATASIZE], gasLimit: 11, memoryLimit: 32)
                m.returnData = Machine.ReturnData(buffer: [0xa0, 0xb0, 0, 0xc0, 0xd0], length: 1, offset: 7)
                m.returnRange = 8 ..< 15
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [UInt8](repeating: 0xee, count: 32), size: 32)).to(beSuccess())
                m.gas.recordRefund(refund: 5)
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                Self.pushArguments(m, size: U256(from: 3), dataOffset: U256(from: 2), memoryOffset: U256(from: 1))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 99), U256(from: 5)]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.gas.refunded).to(equal(5))
                expect(m.memory.get(offset: 0, size: 32)).to(equal([0xee, 0, 0xc0, 0xd0] + [UInt8](repeating: 0xee, count: 28)))
                expect(m.returnRange).to(equal(8 ..< 15))
                expect(m.returnData.buffer).to(equal([0xa0, 0xb0, 0, 0xc0, 0xd0]))
                expect(m.returnData.length).to(equal(1))
                expect(m.returnData.offset).to(equal(7))
            }

            it("charges quadratic expansion once and reads a replacement buffer") {
                let m = TestMachine.machine(opcodes: [.RETURNDATACOPY, .RETURNDATACOPY], gasLimit: 82, memoryLimit: 736)
                m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                Self.pushArguments(m, size: U256(from: 1), memoryOffset: U256(from: 704))

                m.step()

                expect(m.machineStatus).to(equal(.Continue))
                expect(m.gas.remaining).to(equal(6))
                expect(m.gas.memoryGas.numWords).to(equal(23))
                expect(m.gas.memoryGas.gasCost).to(equal(70))
                expect(m.memory.get(offset: 704, size: 1)).to(equal([0xab]))
                // Supply the next call's output directly; executor integration is a later stage.
                m.returnData = Machine.ReturnData(buffer: [0xcd], length: 0, offset: 0)
                Self.pushArguments(m, size: U256(from: 1), memoryOffset: U256(from: 704))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.gas.memoryGas.gasCost).to(equal(70))
                expect(m.memory.effectiveLength).to(equal(736))
                expect(m.memory.get(offset: 703, size: 3)).to(equal([0, 0xcd, 0]))
                expect(m.stack.data).to(beEmpty())
            }

            it("preserves operands when opcode or memory gas cannot be paid") {
                for (budget, remaining, words): (UInt64, UInt64, Int) in [(0, 0, 0), (2, 2, 0), (5, 5, 0), (8, 2, 1)] {
                    let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: budget)
                    m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                    Self.pushArguments(m, size: U256(from: 1))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(remaining))
                    expect(m.gas.memoryGas.numWords).to(equal(words))
                    expect(m.memory.effectiveLength).to(equal(0))
                    expect(m.pc).to(equal(0))
                }
            }

            it("reports unpaid memory before an invalid source range") {
                let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 8)
                Self.pushArguments(m, size: U256(from: 1), dataOffset: .MAX)
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(2))
                expect(m.stack.data).to(equal(original))
                expect(m.memory.effectiveLength).to(equal(0))
            }

            it("consumes only its three operands on a full stack") {
                let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 9)
                m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                for _ in 0 ..< m.stack.limit - 3 {
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                }
                let original = m.stack.data
                Self.pushArguments(m, size: U256(from: 1))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.data).to(equal(original))
                expect(m.memory.get(offset: 0, size: 1)).to(equal([0xab]))
            }

            it("rejects unrepresentable sizes and destinations and overflowing memory ranges") {
                let cases: [(U256, U256, UInt64)] = [
                    (.MAX, .ZERO, 100), (U256(from: UInt64(Int.max) + 1), .ZERO, 100),
                    (U256(from: 1), .MAX, 100), (U256(from: 1), U256(from: UInt64(Int.max)), 94)
                ]
                for (size, destination, remaining) in cases {
                    let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 100)
                    m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                    Self.pushArguments(m, size: size, memoryOffset: destination)
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(remaining))
                    expect(m.memory.effectiveLength).to(equal(0))
                    expect(m.gas.memoryGas.numWords).to(equal(0))
                }
            }

            it("rejects unrepresentable memory gas without allocating") {
                let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: UInt64.max)
                Self.pushArguments(m, size: U256(from: UInt64(Int.max)))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(UInt64.max - 3 - 3 * (UInt64(Int.max) / 32 + 1)))
                expect(m.stack.length).to(equal(3))
                expect(m.memory.effectiveLength).to(equal(0))
            }

            it("enforces the memory limit before consuming the stack") {
                let m = TestMachine.machine(opcodes: [.RETURNDATACOPY], gasLimit: 12, memoryLimit: 32)
                m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                Self.pushArguments(m, size: U256(from: 1), memoryOffset: U256(from: 32))
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.data).to(equal(original))
                expect(m.memory.effectiveLength).to(equal(0))
            }

            it("is allowed in a static call") {
                let handler = StaticHandler()
                let m = Machine(data: [], code: [Opcode.RETURNDATACOPY.rawValue], gasLimit: 9, memoryLimit: 32,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Byzantium)
                m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                Self.pushArguments(m, size: U256(from: 1))
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 0, size: 1)).to(equal([0xab]))
                expect(m.stack.data).to(beEmpty())
                expect(m.gas.remaining).to(equal(0))
                expect(handler.logs).to(beEmpty())
            }

            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            it("reports allocation failure without consuming operands or changing return data") {
                for initialized in [false, true] {
                    let memory = FailingAllocationMemory()
                    let m = Machine(data: [], code: [Opcode.RETURNDATACOPY.rawValue], gasLimit: 12,
                                    context: TestMachine.defaultContext(), state: ExecutionState(), handler: TestHandler(), memory: memory)
                    if initialized { expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue()) }
                    memory.failAllocations = true
                    m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                    Self.pushArguments(m, size: U256(from: 1), memoryOffset: U256(from: 32))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Fatal(.ReadMemory))))
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.stack.data).to(equal(original))
                    expect(memory.effectiveLength).to(equal(initialized ? 32 : 0))
                    expect(m.returnData.buffer).to(equal([0xab]))
                }
            }
            #endif

            #if TRACING
            it("traces all three operands, memory and the full gas charge") {
                let m = TestMachine.machine(opcode: .RETURNDATACOPY, gasLimit: 12)
                m.returnData = Machine.ReturnData(buffer: [0xab, 0xcd, 0xef], length: 0, offset: 0)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                Self.pushArguments(m, size: U256(from: 1), dataOffset: U256(from: 2), memoryOffset: U256(from: 32))
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 32, size: 1)).to(equal([0xef]))
                expect(m.trace.beforeEval?.stack?.data).to(equal(original))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.RETURNDATACOPY))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(12))
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
