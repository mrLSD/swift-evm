@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionBlockHashSpec: QuickSpec {
    override class func spec() {
        describe("Instruction BLOCKHASH") {
            it("enforces the 256-block window at the exact gas budget on every hard fork") {
                let hash = H256(from: (0 ..< 32).map { UInt8($0) })
                let word = U256(l0: 0x1819_1a1b_1c1d_1e1f, l1: 0x1011_1213_1415_1617,
                                h0: 0x0809_0a0b_0c0d_0e0f, h1: 0x0001_0203_0405_0607)
                let cases: [(U256, Bool)] = [
                    (.ZERO, false), (U256(from: 255), false), (U256(from: 256), true),
                    (U256(from: 257), true), (U256(from: 511), true), (U256(from: 512), false),
                    (U256(from: 513), false), (U256(from: UInt64.max), false), (.MAX, false),
                    (U256(l0: 511, l1: 1, h0: 0, h1: 0), false),
                    (U256(l0: 511, l1: 0, h0: 1, h1: 0), false),
                    (U256(l0: 511, l1: 0, h0: 0, h1: 1), false)
                ]
                for fork in HardFork.allCases {
                    for (number, available) in cases {
                        let m = TestMachine.machine(opcodes: [.BLOCKHASH], gasLimit: 20, memoryLimit: 0, hardFork: fork)
                        let handler = m.handler as! TestHandler
                        handler.blockNumberValue = U256(from: 512)
                        handler.blockHashes[number] = hash
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        expect(m.stack.push(value: number)).to(beSuccess())
                        let detail = "fork \(fork), requested block \(number)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), available ? word : .ZERO]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(handler.blockNumberRequests).to(equal(1), description: detail)
                        expect(handler.blockHashRequests).to(equal(available ? [number] : []), description: detail)
                    }
                }
            }

            it("passes the absolute block number for each of the 256 ancestors") {
                for distance in 1 ... 256 {
                    let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 20)
                    let handler = m.handler as! TestHandler
                    let number = U256(from: UInt64(1000 - distance))
                    let expected = U256(from: UInt64(2000 + distance))
                    handler.blockNumberValue = U256(from: 1000)
                    handler.blockHashes[number] = H256(from: expected)
                    expect(m.stack.push(value: number)).to(beSuccess())
                    let detail = "distance \(distance)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                    expect(m.stack.data).to(equal([expected]), description: detail)
                    expect(m.gas.remaining).to(equal(0), description: detail)
                    expect(handler.blockHashRequests).to(equal([number]), description: detail)
                }
            }

            it("handles genesis and the first 257 blocks without unsigned underflow") {
                for current: UInt64 in [0, 1, 2, 255, 256, 257] {
                    for requested: UInt64 in [0, 1, 2, 254, 255, 256, 257, 258] {
                        let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 20)
                        let handler = m.handler as! TestHandler
                        let number = U256(from: requested)
                        handler.blockNumberValue = U256(from: current)
                        handler.blockHashes[number] = .MAX
                        expect(m.stack.push(value: number)).to(beSuccess())
                        let available = requested < current && current - requested <= 256
                        let detail = "current \(current), requested \(requested)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([available ? .MAX : .ZERO]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(handler.blockHashRequests).to(equal(available ? [number] : []), description: detail)
                    }
                }
            }

            it("compares full-width block numbers across limb boundaries and near U256 max") {
                let max = UInt64.max
                let cases: [(U256, U256, Bool)] = [
                    (U256(from: [0, 1, 0, 0]), U256(from: [max, 0, 0, 0]), true),
                    (U256(from: [0, 1, 0, 0]), U256(from: [max - 255, 0, 0, 0]), true),
                    (U256(from: [0, 1, 0, 0]), U256(from: [max - 256, 0, 0, 0]), false),
                    (U256(from: [0, 0, 1, 0]), U256(from: [max, max, 0, 0]), true),
                    (U256(from: [0, 0, 1, 0]), U256(from: [max - 255, max, 0, 0]), true),
                    (U256(from: [0, 0, 1, 0]), U256(from: [max - 256, max, 0, 0]), false),
                    (U256(from: [0, 0, 0, 1]), U256(from: [max, max, max, 0]), true),
                    (U256(from: [0, 0, 0, 1]), U256(from: [max - 255, max, max, 0]), true),
                    (U256(from: [0, 0, 0, 1]), U256(from: [max - 256, max, max, 0]), false),
                    (.MAX, U256(from: [max - 1, max, max, max]), true),
                    (.MAX, U256(from: [max - 256, max, max, max]), true),
                    (.MAX, U256(from: [max - 257, max, max, max]), false),
                    (.MAX, .ZERO, false), (.MAX, .MAX, false),
                    (U256(from: [0, 1, 0, 0]), .ZERO, false),
                    (U256(from: [0, 0, 1, 0]), .ZERO, false),
                    (U256(from: [0, 0, 0, 1]), .ZERO, false)
                ]
                for (current, number, available) in cases {
                    let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 20)
                    let handler = m.handler as! TestHandler
                    handler.blockNumberValue = current
                    handler.blockHashes[number] = .MAX
                    expect(m.stack.push(value: number)).to(beSuccess())
                    let detail = "current \(current), requested \(number)"

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                    expect(m.stack.data).to(equal([available ? .MAX : .ZERO]), description: detail)
                    expect(m.gas.remaining).to(equal(0), description: detail)
                    expect(handler.blockHashRequests).to(equal(available ? [number] : []), description: detail)
                }
            }

            it("preserves a zero hash returned by the handler for an eligible block") {
                let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 20)
                let handler = m.handler as! TestHandler
                handler.blockNumberValue = U256(from: 1)
                expect(m.stack.push(value: .ZERO)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockHashRequests).to(equal([U256.ZERO]))
            }

            it("rejects stack underflow before charging gas or querying the handler") {
                for budget: UInt64 in [0, 19, 20, 100] {
                    let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: budget)
                    let handler = m.handler as! TestHandler

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                    expect(m.stack.data).to(beEmpty())
                    expect(m.gas.remaining).to(equal(budget))
                    expect(m.pc).to(equal(0))
                    expect(handler.blockNumberRequests).to(equal(0))
                    expect(handler.blockHashRequests).to(beEmpty())
                }
            }

            it("preserves the stack and avoids handler reads when gas is insufficient") {
                for budget: UInt64 in [0, 1, 19] {
                    for number in [U256.ZERO, U256(from: 1), U256.MAX] {
                        let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: budget)
                        let handler = m.handler as! TestHandler
                        handler.blockNumberValue = U256(from: 2)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        expect(m.stack.push(value: number)).to(beSuccess())
                        let detail = "gas budget \(budget), requested \(number)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), number]), description: detail)
                        expect(m.gas.remaining).to(equal(budget), description: detail)
                        expect(m.pc).to(equal(0), description: detail)
                        expect(handler.blockNumberRequests).to(equal(0), description: detail)
                        expect(handler.blockHashRequests).to(beEmpty(), description: detail)
                    }
                }
            }

            it("replaces the top word on a full stack without overflowing") {
                let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 20)
                let handler = m.handler as! TestHandler
                handler.blockNumberValue = U256(from: 1024)
                handler.blockHashes[U256(from: 1023)] = .MAX
                for i in 0 ..< m.stack.limit {
                    expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                }
                var expected = m.stack.data
                expected[expected.count - 1] = .MAX

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(expected))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockHashRequests).to(equal([U256(from: 1023)]))
            }

            it("charges the same cost for repeated reads without warm access discounts") {
                for budget: UInt64 in [45, 46] {
                    let m = TestMachine.machine(opcodes: [.DUP1, .BLOCKHASH, .SWAP1, .BLOCKHASH], gasLimit: budget)
                    let handler = m.handler as! TestHandler
                    handler.blockNumberValue = U256(from: 2)
                    handler.blockHashes[U256(from: 1)] = .MAX
                    expect(m.stack.push(value: U256(from: 1))).to(beSuccess())

                    m.evalLoop()

                    if budget == 46 {
                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([U256.MAX, U256.MAX]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.pc).to(equal(4))
                        expect(handler.blockNumberRequests).to(equal(2))
                        expect(handler.blockHashRequests).to(equal([U256(from: 1), U256(from: 1)]))
                    } else {
                        expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                        expect(m.stack.data).to(equal([U256.MAX, U256(from: 1)]))
                        expect(m.gas.remaining).to(equal(19))
                        expect(m.pc).to(equal(3))
                        expect(handler.blockNumberRequests).to(equal(1))
                        expect(handler.blockHashRequests).to(equal([U256(from: 1)]))
                    }
                }
            }

            it("preserves memory and gas refunds") {
                let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 30)
                let handler = m.handler as! TestHandler
                handler.blockNumberValue = U256(from: 1)
                handler.blockHashes[.ZERO] = .MAX
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
                expect(m.gas.remaining).to(equal(7))
            }

            it("is allowed in a static call") {
                let handler = StaticHandler()
                handler.blockNumberValue = U256(from: 1)
                handler.blockHashes[.ZERO] = .MAX
                let m = Machine(data: [], code: [Opcode.BLOCKHASH.rawValue], gasLimit: 20, memoryLimit: 0,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Byzantium)
                expect(m.stack.push(value: .ZERO)).to(beSuccess())
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.MAX]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.blockHashRequests).to(equal([U256.ZERO]))
                expect(handler.logs).to(beEmpty())
            }

            #if TRACING
            it("traces the consumed number, returned hash and instruction cost") {
                for number in [U256(from: 1), U256(from: 2)] {
                    let m = TestMachine.machine(opcode: .BLOCKHASH, gasLimit: 30)
                    let handler = m.handler as! TestHandler
                    handler.blockNumberValue = U256(from: 2)
                    handler.blockHashes[number] = .MAX
                    let expected = number == U256(from: 1) ? U256.MAX : U256.ZERO
                    m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                    expect(m.stack.push(value: number)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99), number]))
                    expect(m.trace.data.count).to(equal(1))
                    expect(m.trace.data.first?.opcode).to(equal(.BLOCKHASH))
                    expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), expected]))
                    expect(m.trace.data.first?.tracedGas?.used).to(equal(20))
                    expect(m.trace.data.first?.tracedGas?.remaining).to(equal(10))
                    #if TRACE_STACK_INOUT
                    expect(m.trace.data.first?.stackOut).to(equal([number]))
                    expect(m.trace.data.first?.stackIn).to(equal([expected]))
                    #endif
                }
            }
            #endif
        }
    }
}
