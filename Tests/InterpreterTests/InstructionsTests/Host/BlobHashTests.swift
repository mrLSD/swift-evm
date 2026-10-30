@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionBlobHashSpec: QuickSpec {
    override class func spec() {
        describe("Instruction BLOBHASH") {
            it("returns transaction hashes and zero outside the list from Cancun onward") {
                let hashes = [
                    U256(l0: 0x1819_1a1b_1c1d_1e1f, l1: 0x1011_1213_1415_1617,
                         h0: 0x0809_0a0b_0c0d_0e0f, h1: 0x0101_0203_0405_0607),
                    U256(l0: 0xffee_ddcc_bbaa_9988, l1: 0x7766_5544_3322_1100,
                         h0: 0x8877_6655_4433_2211, h1: 0x01ff_eedd_ccbb_aa99)
                ]
                let cases: [(U256, UInt, U256)] = [
                    (.ZERO, 0, hashes[0]), (U256(from: 1), 1, hashes[1]),
                    (U256(from: 2), 2, .ZERO), (U256(from: 3), 3, .ZERO),
                    (U256(from: UInt64(Int.max)), UInt(Int.max), .ZERO),
                    (U256(from: UInt64(Int.max) + 1), UInt(Int.max) + 1, .ZERO),
                    (U256(from: UInt64(UInt.max)), UInt.max, .ZERO),
                    (U256(l0: 0, l1: 1, h0: 0, h1: 0), UInt.max, .ZERO),
                    (U256(l0: 1, l1: 1, h0: 0, h1: 0), UInt.max, .ZERO),
                    (U256(l0: 1, l1: 0, h0: 1, h1: 0), UInt.max, .ZERO),
                    (U256(l0: 1, l1: 0, h0: 0, h1: 1), UInt.max, .ZERO),
                    (.MAX, UInt.max, .ZERO)
                ]
                let forks = HardFork.allCases.drop(while: { $0 != .Cancun })
                expect(forks.first).to(equal(.Cancun))
                for fork in forks {
                    for (index, requested, expected) in cases {
                        let m = TestMachine.machine(opcodes: [.BLOBHASH], gasLimit: 3, memoryLimit: 0, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.blobVersionedHashes = hashes
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        expect(m.stack.push(value: index)).to(beSuccess())
                        let detail = "fork \(fork), index \(index)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), expected]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(handler.blobHashRequests).to(equal([requested]), description: detail)
                        expect(handler.blockHashRequests).to(beEmpty(), description: detail)
                    }
                }
            }

            it("rejects every pre-Cancun fork before inspecting the stack, gas or handler") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Cancun })
                expect(forks.last).to(equal(.Shanghai))
                for fork in forks {
                    for budget: UInt64 in [0, 2, 3, 10] {
                        for hasIndex in [false, true] {
                            let m = TestMachine.machine(opcodes: [.BLOBHASH], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                            if hasIndex {
                                expect(m.stack.push(value: U256.ZERO)).to(beSuccess())
                            }
                            let original = m.stack.data
                            let detail = "fork \(fork), gas \(budget), index present \(hasIndex)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: detail)
                            expect(m.stack.data).to(equal(original), description: detail)
                            expect(m.gas.remaining).to(equal(budget), description: detail)
                            expect(m.pc).to(equal(0), description: detail)
                            expect((m.handler as! TestHandler).blobHashRequests).to(beEmpty(), description: detail)
                        }
                    }
                }
            }

            it("returns zero for transactions without blobs on every active fork") {
                for fork in HardFork.allCases.drop(while: { $0 != .Cancun }) {
                    for index in [U256.ZERO, U256(from: 1), U256.MAX] {
                        let m = TestMachine.machine(opcodes: [.BLOBHASH], gasLimit: 3, memoryLimit: 0, hardFork: fork)
                        expect(m.stack.push(value: index)).to(beSuccess())
                        let detail = "fork \(fork), index \(index)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256.ZERO]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blobHashRequests.count).to(equal(1), description: detail)
                    }
                }
            }

            it("preserves handler words without hashing or masking their contents") {
                for word in [U256.ZERO, U256(from: 1), U256.MAX] {
                    let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: 3)
                    let handler = m.handler as! TestHandler
                    handler.blobVersionedHashes = [word]
                    expect(m.stack.push(value: .ZERO)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([word]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.blobHashRequests).to(equal([0]))
                }
            }

            it("reads all nine Prague transaction hashes without a Cancun-era limit") {
                let hashes = (0 ..< 9).map { U256(l0: UInt64($0 + 1), l1: 0, h0: 0, h1: 0x0100_0000_0000_0000) }
                for index in 0 ... hashes.count {
                    let m = TestMachine.machine(opcodes: [.BLOBHASH], gasLimit: 3, memoryLimit: 0, hardFork: .Prague)
                    let handler = m.handler as! TestHandler
                    handler.blobVersionedHashes = hashes
                    expect(m.stack.push(value: U256(from: UInt64(index)))).to(beSuccess())
                    let expected = index < hashes.count ? hashes[index] : .ZERO

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([expected]), description: "index \(index)")
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.blobHashRequests).to(equal([UInt(index)]))
                }
            }

            it("rejects stack underflow before charging gas or querying the handler") {
                for budget: UInt64 in [0, 2, 3, 10] {
                    let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: budget)

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                    expect(m.stack.data).to(beEmpty())
                    expect(m.gas.remaining).to(equal(budget))
                    expect(m.pc).to(equal(0))
                    expect((m.handler as! TestHandler).blobHashRequests).to(beEmpty())
                }
            }

            it("preserves the stack and avoids handler reads when gas is insufficient") {
                for budget: UInt64 in [0, 1, 2] {
                    for index in [U256.ZERO, U256(from: 2), U256.MAX] {
                        let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: budget)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        expect(m.stack.push(value: index)).to(beSuccess())
                        let detail = "gas \(budget), index \(index)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), index]), description: detail)
                        expect(m.gas.remaining).to(equal(budget), description: detail)
                        expect(m.pc).to(equal(0), description: detail)
                        expect((m.handler as! TestHandler).blobHashRequests).to(beEmpty(), description: detail)
                    }
                }
            }

            it("replaces the top word on a full stack without overflowing") {
                let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: 3)
                let handler = m.handler as! TestHandler
                handler.blobVersionedHashes = [.MAX]
                for _ in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                }
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                var expected = m.stack.data
                expected[expected.count - 1] = .MAX

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(expected))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blobHashRequests).to(equal([0]))
            }

            it("charges three gas for each read and does not query an unpaid instruction") {
                for budget: UInt64 in [11, 12] {
                    let m = TestMachine.machine(opcodes: [.DUP1, .BLOBHASH, .SWAP1, .BLOBHASH], gasLimit: budget)
                    let handler = m.handler as! TestHandler
                    handler.blobVersionedHashes = [.MAX]
                    expect(m.stack.push(value: .ZERO)).to(beSuccess())

                    m.evalLoop()

                    if budget == 12 {
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([U256.MAX, U256.MAX]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.pc).to(equal(4))
                        expect(handler.blobHashRequests).to(equal([0, 0]))
                    } else {
                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.stack.data).to(equal([U256.MAX, U256.ZERO]))
                        expect(m.gas.remaining).to(equal(2))
                        expect(m.pc).to(equal(3))
                        expect(handler.blobHashRequests).to(equal([0]))
                    }
                }
            }

            it("preserves memory and gas refunds") {
                let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: 10)
                let handler = m.handler as! TestHandler
                handler.blobVersionedHashes = [.MAX]
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                m.gas.recordRefund(refund: 5)
                let memory = m.memory.get(offset: 0, size: 32)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.MAX]))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.gas.refunded).to(equal(5))
                expect(m.gas.remaining).to(equal(4))
            }

            it("is allowed in a static call from Cancun") {
                let handler = StaticHandler()
                handler.blobVersionedHashes = [.MAX]
                let m = Machine(data: [], code: [Opcode.BLOBHASH.rawValue], gasLimit: 3, memoryLimit: 0,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Cancun)
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.MAX]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blobHashRequests).to(equal([0]))
                expect(handler.logs).to(beEmpty())
            }

            #if TRACING
            it("traces the consumed index, returned word and instruction cost") {
                for index in [U256.ZERO, U256(from: 1), U256.MAX] {
                    let m = TestMachine.machine(opcode: .BLOBHASH, gasLimit: 10)
                    let handler = m.handler as! TestHandler
                    handler.blobVersionedHashes = [.MAX]
                    let expected = index == .ZERO ? U256.MAX : U256.ZERO
                    m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                    expect(m.stack.push(value: index)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99), index]))
                    expect(m.trace.data.count).to(equal(1))
                    expect(m.trace.data.first?.opcode).to(equal(.BLOBHASH))
                    expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), expected]))
                    expect(m.trace.data.first?.tracedGas?.used).to(equal(3))
                    expect(m.trace.data.first?.tracedGas?.remaining).to(equal(7))
                    #if TRACE_STACK_INOUT
                    expect(m.trace.data.first?.stackOut).to(equal([index]))
                    expect(m.trace.data.first?.stackIn).to(equal([expected]))
                    #endif
                }
            }
            #endif
        }
    }
}
