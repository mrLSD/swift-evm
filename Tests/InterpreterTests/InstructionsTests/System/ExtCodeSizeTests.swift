@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExtCodeSizeSpec: QuickSpec {
    private static var prices: [(HardFork, UInt64)] {
        [
            (.Frontier, 20), (.Homestead, 20), (.Tangerine, 700), (.SpuriousDragon, 700),
            (.Byzantium, 700), (.Constantinople, 700), (.Istanbul, 700), (.Berlin, 2600),
            (.London, 2600), (.Paris, 2600), (.Shanghai, 2600), (.Cancun, 2600), (.Prague, 2600), (.Osaka, 2600)
        ]
    }

    override class func spec() {
        describe("Instruction EXTCODESIZE") {
            let address = TestHandler.address1
            let word = U256(from: H256(from: address))

            it("returns the byte length at the exact gas budget on every hard fork") {
                for (fork, coldCost) in Self.prices {
                    for warm in [false, true] {
                        for size in [0, 1, 31, 32, 33, 255, 256, 24576] {
                            let cost = warm && coldCost == 2600 ? 100 : coldCost
                            let m = TestMachine.machine(opcodes: [.EXTCODESIZE], gasLimit: cost, memoryLimit: 0, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.codes[address] = [UInt8](repeating: 0xfe, count: size)
                            if warm { m.state.warm(address: address) }
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())
                            let detail = "fork \(fork), warm \(warm), size \(size)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 99), U256(from: UInt64(size))]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(m.memory.effectiveLength).to(equal(0), description: detail)
                            expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                            expect(handler.codeRequests).to(equal([address]), description: detail)
                            expect(m.state.isCold(address: address)).to(equal(!warm && coldCost != 2600), description: detail)
                        }
                    }
                }
            }

            it("rejects an empty stack before charging or reading code") {
                let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 0)
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
                expect(m.state.isCold(address: .ZERO)).to(beTrue())
            }

            it("preserves operands and does not read code when gas is insufficient") {
                for (fork, coldCost) in Self.prices {
                    for warm in [false, true] {
                        let cost = warm && coldCost == 2600 ? 100 : coldCost
                        for budget in [UInt64(0), cost - 1] {
                            let m = TestMachine.machine(opcodes: [.EXTCODESIZE], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                            if warm { m.state.warm(address: address) }
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())
                            let original = m.stack.data
                            let detail = "fork \(fork), warm \(warm), budget \(budget)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))), description: detail)
                            expect(m.stack.data).to(equal(original), description: detail)
                            expect(m.gas.remaining).to(equal(budget), description: detail)
                            expect((m.handler as! TestHandler).codeRequests).to(beEmpty(), description: detail)
                            expect(m.state.isCold(address: address)).to(equal(!warm && coldCost != 2600), description: detail)
                        }
                    }
                }
            }

            it("replaces the top of a full stack without overflowing") {
                let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 2600)
                let handler = m.handler as! TestHandler
                handler.codes[address] = [0x60, 0x00, 0x00]
                for _ in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                }
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256](repeating: U256(from: 99), count: m.stack.limit - 1) + [U256(from: 3)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.codeRequests).to(equal([address]))
            }

            it("returns zero for absent accounts and accounts with empty code") {
                for target in [H160.ZERO, TestHandler.address2, H160.MAX] {
                    for present in [false, true] {
                        let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 2600)
                        let handler = m.handler as! TestHandler
                        if present { handler.codes[target] = [] }
                        expect(m.stack.push(value: U256(from: H256(from: target)))).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([U256.ZERO]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(handler.codeRequests).to(equal([target]))
                        expect(m.state.isCold(address: target)).to(beFalse())
                    }
                }
            }

            it("ignores all high 96 address bits for lookup and warming") {
                for bit in 160 ..< 256 {
                    let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 100)
                    let handler = m.handler as! TestHandler
                    handler.codes[address] = [0xaa, 0xbb]
                    m.state.warm(address: address)
                    expect(m.stack.push(value: word | (U256(from: 1) << bit))).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "bit \(bit)")
                    expect(m.stack.data).to(equal([U256(from: 2)]), description: "bit \(bit)")
                    expect(m.gas.remaining).to(equal(0), description: "bit \(bit)")
                    expect(handler.codeRequests).to(equal([address]), description: "bit \(bit)")
                }
            }

            it("charges cold then warm access for repeated queries") {
                let m = TestMachine.machine(opcodes: [.EXTCODESIZE, .POP, .EXTCODESIZE], gasLimit: 2702)
                let handler = m.handler as! TestHandler
                handler.codes[address] = [0x00]
                expect(m.stack.push(value: word)).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 1)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.codeRequests).to(equal([address, address]))
            }

            it("shares account warming with BALANCE and EXTCODECOPY in both directions") {
                for other in [Opcode.BALANCE, .EXTCODECOPY] {
                    for sizeFirst in [false, true] {
                        let order: [Opcode] = sizeFirst ? [.EXTCODESIZE, other] : [other, .EXTCODESIZE]
                        let opcodes = order.flatMap { $0 == .EXTCODECOPY ? [$0] : [$0, .POP] }
                        let cost: UInt64 = other == .EXTCODECOPY ? 2702 : 2704
                        let m = TestMachine.machine(opcodes: opcodes, gasLimit: cost)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        for opcode in order.reversed() {
                            if opcode == .EXTCODECOPY {
                                for _ in 0 ..< 3 { expect(m.stack.push(value: .ZERO)).to(beSuccess()) }
                            }
                            expect(m.stack.push(value: word)).to(beSuccess())
                        }

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([U256(from: 99)]))
                        expect(m.gas.remaining).to(equal(0))
                        expect((m.handler as! TestHandler).codeRequests).to(equal([address]))
                        expect(m.state.isCold(address: address)).to(beFalse())
                    }
                }
            }

            it("reads account code rather than the currently executing initialization code") {
                let m = TestMachine.machineWithContext(opcode: .EXTCODESIZE, gasLimit: 2600, context: Machine.Context(targetAddress: address, callerAddress: .ZERO, callValue: .ZERO))
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.codeSize).to(equal(1))
                expect(m.stack.data).to(equal([U256.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).codeRequests).to(equal([address]))
            }

            it("preserves existing memory and its gas counters") {
                let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 2603)
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                let memory = m.memory.get(offset: 0, size: 32)
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256.ZERO]))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.gas.memoryGas.numWords).to(equal(1))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.gas.remaining).to(equal(0))
            }

            it("returns the delegation indicator size in static calls without accessing the delegate") {
                for fork in [HardFork.Prague, .Osaka] {
                    let handler = StaticHandler()
                    handler.codes[address] = [0xef, 0x01, 0x00] + TestHandler.address2.BYTES
                    handler.codes[TestHandler.address2] = [UInt8](repeating: 0x00, count: 64)
                    let m = Machine(data: [], code: [Opcode.EXTCODESIZE.rawValue], gasLimit: 2600, memoryLimit: 0, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: fork)
                    expect(handler.isStatic()).to(beTrue())
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([U256(from: 23)]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(handler.codeRequests).to(equal([address]))
                    expect(m.state.isCold(address: address)).to(beFalse())
                    expect(m.state.isCold(address: TestHandler.address2)).to(beTrue())
                    expect(handler.logs).to(beEmpty())
                }
            }

            #if TRACING
            it("traces the address, result and account access gas") {
                let m = TestMachine.machine(opcode: .EXTCODESIZE, gasLimit: 3000)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                (m.handler as! TestHandler).codes[address] = [0xaa, 0xbb]
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                expect(m.stack.push(value: word)).to(beSuccess())
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.beforeEval?.stack?.data).to(equal(original))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.EXTCODESIZE))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), U256(from: 2)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2600))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(400))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word]))
                expect(m.trace.data.first?.stackIn).to(equal([U256(from: 2)]))
                #endif
            }
            #endif
        }
    }
}
