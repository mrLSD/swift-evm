@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExtCodeCopySpec: QuickSpec {
    private static func pushExtCodeArguments(_ m: Machine, size: U256, codeOffset: U256 = .ZERO, memoryOffset: U256 = .ZERO, address: U256 = U256(from: H256(from: TestHandler.address1))) {
        expect(m.stack.push(value: size)).to(beSuccess())
        expect(m.stack.push(value: codeOffset)).to(beSuccess())
        expect(m.stack.push(value: memoryOffset)).to(beSuccess())
        expect(m.stack.push(value: address)).to(beSuccess())
    }

    override class func spec() {
        describe("Instruction EXTCODECOPY") {
            let address = TestHandler.address1
            let word = U256(from: H256(from: address))
            let prices: [(HardFork, UInt64)] = [
                (.Frontier, 20), (.Homestead, 20), (.Tangerine, 700), (.SpuriousDragon, 700),
                (.Byzantium, 700), (.Constantinople, 700), (.Istanbul, 700), (.Berlin, 2600),
                (.London, 2600), (.Paris, 2600), (.Shanghai, 2600), (.Cancun, 2600), (.Prague, 2600), (.Osaka, 2600)
            ]

            it("charges exact access, copy and memory gas on every hard fork") {
                for (fork, coldCost) in prices {
                    for warm in [false, true] {
                        for (size, words) in [(0, 0), (1, 1), (31, 1), (32, 1), (33, 2)] {
                            let accessCost = warm && coldCost == 2600 ? 100 : coldCost
                            let cost: UInt64 = accessCost + UInt64(6 * words)
                            let m = TestMachine.machine(opcodes: [.EXTCODECOPY], gasLimit: cost, memoryLimit: 1024, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.codes[address] = Array(0 ... 63)
                            if warm {
                                m.state.warm(address: address)
                            }
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            Self.pushExtCodeArguments(m, size: U256(from: UInt64(size)))
                            let detail = "fork \(fork), warm \(warm), size \(size)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 99)]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(m.memory.effectiveLength).to(equal(32 * words), description: detail)
                            expect(m.gas.memoryGas.gasCost).to(equal(UInt64(3 * words)), description: detail)
                            expect(m.memory.get(offset: 0, size: size)).to(equal(Array(handler.codes[address]!.prefix(size))), description: detail)
                            expect(handler.codeRequests).to(equal(size == 0 ? [] : [address]), description: detail)
                            expect(m.state.isCold(address: address)).to(equal(!warm && coldCost != 2600), description: detail)
                        }
                    }
                }
            }

            it("rejects every insufficient stack depth before gas or account access") {
                for count in 0 ..< 4 {
                    let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 3000)
                    for _ in 0 ..< count {
                        expect(m.stack.push(value: .ZERO)).to(beSuccess())
                    }

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                    expect(m.stack.length).to(equal(count))
                    expect(m.gas.remaining).to(equal(3000))
                    expect(m.state.accessed.addresses).to(beEmpty())
                    expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
                }
            }

            it("ignores both oversized offsets for zero length but charges and warms the account") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 2600)
                Self.pushExtCodeArguments(m, size: .ZERO, codeOffset: .MAX, memoryOffset: .MAX)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
                expect(m.memory.effectiveLength).to(equal(0))
                expect(m.state.isCold(address: address)).to(beFalse())
                expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
            }

            it("masks the upper 96 address bits for lookup and warming") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 2606)
                let handler = m.handler as! TestHandler
                handler.codes[address] = [0xab]
                let masked = word | (U256.MAX << 160)
                Self.pushExtCodeArguments(m, size: U256(from: 1), address: masked)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 0, size: 1)).to(equal([0xab]))
                expect(handler.codeRequests).to(equal([address]))
                expect(m.state.accessed.addresses).to(equal(Set([address])))
                expect(m.gas.remaining).to(equal(0))
            }

            it("copies slices and clears only the requested range past the code end") {
                let code = Array(UInt8(0) ... UInt8(64))
                for source in [0, 1, 31, 32, 64, 65, 66] {
                    for destination in [0, 1, 31, 32, 63] {
                        for size in [1, 31, 32, 33, 65] {
                            let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 10000)
                            let handler = m.handler as! TestHandler
                            handler.codes[address] = code
                            expect(m.resizeMemoryAndRecordGas(offset: 0, size: 160)).to(beTrue())
                            expect(m.memory.set(offset: 0, value: [UInt8](repeating: 0xee, count: 160), size: 160)).to(beSuccess())
                            Self.pushExtCodeArguments(m, size: U256(from: UInt64(size)), codeOffset: U256(from: UInt64(source)), memoryOffset: U256(from: UInt64(destination)))
                            var expected = [UInt8](repeating: 0xee, count: 160)
                            for index in 0 ..< size {
                                expected[destination + index] = source + index < code.count ? code[source + index] : 0
                            }
                            let detail = "source \(source), destination \(destination), size \(size)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.memory.get(offset: 0, size: 160)).to(equal(expected), description: detail)
                            expect(m.memory.effectiveLength).to(equal(160), description: detail)
                            let remaining = 7385 - 3 * ((size + 31) / 32)
                            expect(m.gas.remaining).to(equal(UInt64(remaining)), description: detail)
                            expect(m.stack.length).to(equal(0), description: detail)
                        }
                    }
                }
            }

            it("zero-fills absent and empty accounts, including oversized code offsets") {
                for emptyAccount in [false, true] {
                    for offset in [U256.ZERO, U256(from: UInt64(Int.max)), U256.MAX] {
                        let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 2606)
                        let handler = m.handler as! TestHandler
                        if emptyAccount {
                            handler.codes[address] = []
                        }
                        Self.pushExtCodeArguments(m, size: U256(from: 4), codeOffset: offset)

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.memory.get(offset: 0, size: 4)).to(equal([0, 0, 0, 0]))
                        expect(handler.codeRequests).to(equal([address]))
                        expect(m.gas.remaining).to(equal(0))
                    }
                }
            }

            it("zero-fills an oversized source offset even when the account has code") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 2606)
                (m.handler as! TestHandler).codes[address] = [1, 2, 3]
                Self.pushExtCodeArguments(m, size: U256(from: 3), codeOffset: .MAX)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 0, size: 3)).to(equal([0, 0, 0]))
                expect(m.gas.remaining).to(equal(0))
            }

            it("charges quadratic expansion only for newly allocated memory") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 10000)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                Self.pushExtCodeArguments(m, size: U256(from: 1), memoryOffset: U256(from: 1024))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.effectiveLength).to(equal(1056))
                expect(m.gas.memoryGas.gasCost).to(equal(101))
                expect(m.gas.remaining).to(equal(7296))
            }

            it("shares account warming with BALANCE in both directions") {
                for copyFirst in [false, true] {
                    let ops: [Opcode] = copyFirst ? [.EXTCODECOPY, .BALANCE, .POP] : [.BALANCE, .POP, .EXTCODECOPY]
                    let m = TestMachine.machine(opcodes: ops, gasLimit: 2702)
                    if copyFirst {
                        expect(m.stack.push(value: word)).to(beSuccess())
                    }
                    Self.pushExtCodeArguments(m, size: .ZERO)
                    if !copyFirst {
                        expect(m.stack.push(value: word)).to(beSuccess())
                    }

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.length).to(equal(0))
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.state.accessed.addresses).to(equal(Set([address])))
                }
            }

            it("charges cold then warm for repeated copies and preserves other addresses") {
                let m = TestMachine.machine(opcodes: [.EXTCODECOPY, .EXTCODECOPY], gasLimit: 2700)
                m.state.warm(address: TestHandler.address2)
                Self.pushExtCodeArguments(m, size: .ZERO)
                Self.pushExtCodeArguments(m, size: .ZERO)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.stack.length).to(equal(0))
                expect(m.state.accessed.addresses).to(equal(Set([address, TestHandler.address2])))
            }

            it("uses a parent's warm address without inserting it in the child") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 100)
                let parent = ExecutionState()
                parent.warm(address: address)
                m.state.parent = parent
                Self.pushExtCodeArguments(m, size: .ZERO)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.gas.remaining).to(equal(0))
                expect(m.state.accessed.addresses).to(beEmpty())
                expect(parent.accessed.addresses).to(equal(Set([address])))
            }

            it("fails without consuming operands or reading code when gas is insufficient") {
                for (size, limit, remaining) in [(0, 2599, 2599), (33, 2605, 2605), (1, 2605, 2)] {
                    let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: UInt64(limit))
                    Self.pushExtCodeArguments(m, size: U256(from: UInt64(size)))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(UInt64(remaining)))
                    expect(m.memory.effectiveLength).to(equal(0))
                    expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
                }
            }

            it("rejects unrepresentable size and destination before charging and overflowing ranges after") {
                let cases: [(U256, U256, UInt64)] = [
                    (.MAX, .ZERO, 10000), (U256(from: 1), .MAX, 10000),
                    (U256(from: 1), U256(from: UInt64(Int.max)), 7397)
                ]
                for (size, offset, remaining) in cases {
                    let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 10000)
                    Self.pushExtCodeArguments(m, size: size, memoryOffset: offset)
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(remaining))
                    expect(m.gas.memoryGas.numWords).to(equal(0))
                    expect(m.memory.effectiveLength).to(equal(0))
                    expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
                }
            }

            it("preserves paid memory and operands when the memory charge fails") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 2608)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                Self.pushExtCodeArguments(m, size: U256(from: 1), memoryOffset: U256(from: 32))
                let originalStack = m.stack.data
                let originalMemory = m.memory.get(offset: 0, size: 32)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                // The access and copy cost of 2603 is paid; the second word's 3 gas is not affordable.
                expect(m.gas.remaining).to(equal(2))
                expect(m.gas.memoryGas.numWords).to(equal(2))
                expect(m.gas.memoryGas.gasCost).to(equal(6))
                expect(m.stack.data).to(equal(originalStack))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(originalMemory))
                expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
            }

            it("rejects overflowing memory gas even with the maximum gas budget") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: UInt64.max)
                Self.pushExtCodeArguments(m, size: U256(from: UInt64(Int.max)))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                // The access and copy cost is paid; the memory cost itself is unrepresentable.
                expect(m.gas.remaining).to(equal(UInt64.max - 2600 - 3 * (UInt64(Int.max) / 32 + 1)))
                expect(m.gas.memoryGas.numWords).to(equal(0))
                expect(m.stack.length).to(equal(4))
                expect(m.memory.effectiveLength).to(equal(0))
                expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
            }

            it("enforces the memory limit before reading external code") {
                let m = TestMachine.machine(opcodes: [.EXTCODECOPY], gasLimit: 3000, memoryLimit: 32)
                Self.pushExtCodeArguments(m, size: U256(from: 1), memoryOffset: U256(from: 32))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.length).to(equal(4))
                expect(m.memory.effectiveLength).to(equal(0))
                expect(m.gas.remaining).to(equal(391))
                expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
            }

            it("copies the EIP-7702 indicator in a static call without accessing the delegate") {
                let handler = StaticHandler()
                let indicator: [UInt8] = [0xef, 0x01, 0x00] + TestHandler.address2.BYTES
                handler.codes[address] = indicator
                handler.codes[TestHandler.address2] = [0xaa, 0xbb]
                let m = Machine(data: [], code: [Opcode.EXTCODECOPY.rawValue], gasLimit: 2606, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                expect(handler.isStatic()).to(beTrue())
                Self.pushExtCodeArguments(m, size: U256(from: 25))

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.memory.get(offset: 0, size: 25)).to(equal(indicator + [0, 0]))
                expect(handler.codeRequests).to(equal([address]))
                expect(m.state.isCold(address: TestHandler.address2)).to(beTrue())
                expect(m.gas.remaining).to(equal(0))
            }

            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            it("reports allocation failure before consuming the stack or fetching code") {
                for initialized in [false, true] {
                    let memory = FailingAllocationMemory()
                    let handler = TestHandler()
                    let m = Machine(data: [], code: [Opcode.EXTCODECOPY.rawValue], gasLimit: 3000, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, memory: memory)
                    if initialized {
                        expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                    }
                    memory.failAllocations = true
                    Self.pushExtCodeArguments(m, size: U256(from: 1), memoryOffset: U256(from: 32))
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Fatal(.ReadMemory))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(391))
                    expect(memory.effectiveLength).to(equal(initialized ? 32 : 0))
                    expect(handler.codeRequests).to(beEmpty())
                }
            }
            #endif

            #if TRACING
            it("traces all four operands and the complete gas charge") {
                let m = TestMachine.machine(opcode: .EXTCODECOPY, gasLimit: 3000)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                Self.pushExtCodeArguments(m, size: U256(from: 1), codeOffset: U256(from: 2), memoryOffset: U256(from: 32))
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.beforeEval?.stack?.data).to(equal(original))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.EXTCODECOPY))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2609))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(391))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word, U256(from: 32), U256(from: 2), U256(from: 1)]))
                expect(m.trace.data.first?.stackIn).to(beEmpty())
                #endif
            }
            #endif
        }
    }
}
