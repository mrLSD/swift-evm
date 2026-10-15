@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionExtCodeHashSpec: QuickSpec {
    class StateHandler: TestHandler {
        let state: MemoryState

        init(state: MemoryState) {
            self.state = state
        }

        override func codeHash(address: H160) -> H256 {
            codeHashRequests.append(address)
            return state.extCodeHash(address: address)
        }

        override func isStatic() -> Bool {
            true
        }
    }

    // Rust sha3::Keccak256 of 0xef0100 followed by twenty 0x11 bytes.
    private static var delegationHash: H256 {
        try! H256.fromString(hex: "dfe7c7677e3d245aaff2e3e94db902f5fb37475eb611959c71ee641508dcf49a").get()
    }

    private static var prices: [(HardFork, UInt64)] {
        [
            (.Constantinople, 400), (.Istanbul, 700), (.Berlin, 2600), (.London, 2600),
            (.Paris, 2600), (.Shanghai, 2600), (.Cancun, 2600), (.Prague, 2600), (.Osaka, 2600)
        ]
    }

    override class func spec() {
        describe("Instruction EXTCODEHASH") {
            let address = TestHandler.address1
            let word = U256(from: H256(from: address))
            let hash = try! H256.fromString(hex: "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45").get()

            it("charges exact gas and uses the supplied hash on every active hard fork") {
                for (fork, coldCost) in Self.prices {
                    for warm in [false, true] {
                        for expected in [H256.ZERO, .KECCAK_EMPTY, hash, .MAX] {
                            let cost = warm && coldCost == 2600 ? 100 : coldCost
                            let m = TestMachine.machine(opcodes: [.EXTCODEHASH], gasLimit: cost, memoryLimit: 0, hardFork: fork)
                            let handler = m.handler as! TestHandler
                            handler.codeHashes[address] = expected
                            handler.codes[address] = [0xfe]
                            if warm {
                                m.state.warm(address: address)
                            }
                            expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                            expect(m.stack.push(value: word)).to(beSuccess())
                            let detail = "fork \(fork), warm \(warm), hash \(expected)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                            expect(m.stack.data).to(equal([U256(from: 99), U256(from: expected)]), description: detail)
                            expect(m.gas.remaining).to(equal(0), description: detail)
                            expect(handler.codeHashRequests).to(equal([address]), description: detail)
                            expect(handler.codeRequests).to(beEmpty(), description: detail)
                            expect(m.memory.effectiveLength).to(equal(0), description: detail)
                            expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                            expect(m.state.isCold(address: address)).to(equal(!warm && coldCost != 2600), description: detail)
                        }
                    }
                }
            }

            it("is unavailable before Constantinople, even with an empty stack") {
                for fork in [HardFork.Frontier, .Homestead, .Tangerine, .SpuriousDragon, .Byzantium] {
                    for count in [0, 1] {
                        let m = TestMachine.machine(opcodes: [.EXTCODEHASH], gasLimit: 10000, memoryLimit: 0, hardFork: fork)
                        if count == 1 {
                            expect(m.stack.push(value: word)).to(beSuccess())
                        }
                        let original = m.stack.data

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))))
                        expect(m.stack.data).to(equal(original))
                        expect(m.gas.remaining).to(equal(10000))
                        expect((m.handler as! TestHandler).codeHashRequests).to(beEmpty())
                        expect(m.state.isCold(address: address)).to(beTrue())
                    }
                }
            }

            it("rejects stack underflow before gas or account access") {
                let m = TestMachine.machine(opcode: .EXTCODEHASH, gasLimit: 0)
                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.StackUnderflow))))
                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(0))
                expect((m.handler as! TestHandler).codeHashRequests).to(beEmpty())
                expect(m.state.isCold(address: .ZERO)).to(beTrue())
            }

            it("preserves the stack without requesting a hash when gas is insufficient") {
                for (fork, coldCost) in Self.prices {
                    for warm in [false, true] {
                        let cost = warm && coldCost == 2600 ? 100 : coldCost
                        for budget in [UInt64(0), cost - 1] {
                            let m = TestMachine.machine(opcodes: [.EXTCODEHASH], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                            if warm {
                                m.state.warm(address: address)
                            }
                            expect(m.stack.push(value: word)).to(beSuccess())

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                            expect(m.stack.data).to(equal([word]))
                            expect(m.gas.remaining).to(equal(budget))
                            expect((m.handler as! TestHandler).codeHashRequests).to(beEmpty())
                            expect((m.handler as! TestHandler).codeRequests).to(beEmpty())
                            expect(m.state.isCold(address: address)).to(equal(!warm && coldCost != 2600))
                        }
                    }
                }
            }

            it("replaces a full stack's top and leaves memory unchanged") {
                let m = TestMachine.machine(opcode: .EXTCODEHASH, gasLimit: 2603)
                (m.handler as! TestHandler).codeHashes[address] = hash
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xab], size: 1)).to(beSuccess())
                let memory = m.memory.get(offset: 0, size: 32)
                for _ in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: .MAX)).to(beSuccess())
                }
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256](repeating: .MAX, count: m.stack.limit - 1) + [U256(from: hash)]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
            }

            it("masks all high 96 address bits for lookup and warming") {
                for target in [H160.ZERO, address, H160.MAX] {
                    for bit in 160 ..< 256 {
                        let m = TestMachine.machine(opcode: .EXTCODEHASH, gasLimit: 100)
                        let handler = m.handler as! TestHandler
                        handler.codeHashes[target] = hash
                        m.state.warm(address: target)
                        let operand = U256(from: H256(from: target)) | (U256(from: 1) << bit)
                        expect(m.stack.push(value: operand)).to(beSuccess())

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: "bit \(bit)")
                        expect(m.stack.data).to(equal([U256(from: hash)]), description: "bit \(bit)")
                        expect(m.gas.remaining).to(equal(0))
                        expect(handler.codeHashRequests).to(equal([target]))
                    }
                }
            }

            it("shares warming with EXTCODEHASH, EXTCODESIZE, EXTCODECOPY and BALANCE") {
                for other in [Opcode.EXTCODEHASH, .EXTCODESIZE, .EXTCODECOPY, .BALANCE] {
                    for hashFirst in [false, true] {
                        let order: [Opcode] = hashFirst ? [.EXTCODEHASH, other] : [other, .EXTCODEHASH]
                        let opcodes = order.flatMap { $0 == .EXTCODECOPY ? [$0] : [$0, .POP] }
                        let cost: UInt64 = other == .EXTCODECOPY ? 2702 : 2704
                        let m = TestMachine.machine(opcodes: opcodes, gasLimit: cost)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        for opcode in order.reversed() {
                            if opcode == .EXTCODECOPY {
                                for _ in 0 ..< 3 {
                                    expect(m.stack.push(value: .ZERO)).to(beSuccess())
                                }
                            }
                            expect(m.stack.push(value: word)).to(beSuccess())
                        }

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                        expect(m.stack.data).to(equal([U256(from: 99)]))
                        expect(m.gas.remaining).to(equal(0))
                        expect(m.state.isCold(address: address)).to(beFalse())
                    }
                }
            }

            it("distinguishes absent, empty, funded, nonce-only and code accounts through the backend") {
                for (present, balance, nonce, codeHash, expected) in [
                    (false, UInt64(0), UInt64(0), H256.KECCAK_EMPTY, H256.ZERO),
                    (true, 0, 0, .KECCAK_EMPTY, .ZERO),
                    (true, 1, 0, .KECCAK_EMPTY, .KECCAK_EMPTY),
                    (true, 0, 1, .KECCAK_EMPTY, .KECCAK_EMPTY),
                    (true, 0, 0, hash, hash)
                ] {
                    let backend = MockBackend()
                    if present {
                        backend.accounts[address] = BasicAccount(balance: U256(from: balance), nonce: nonce)
                    }
                    backend.codeHashes[address] = codeHash
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Prague)
                    let handler = StateHandler(state: state)
                    let m = Machine(data: [], code: [Opcode.EXTCODEHASH.rawValue], gasLimit: 2600, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                    expect(m.stack.push(value: word)).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([U256(from: expected)]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(backend.codeHashRequests).to(equal([address]))
                    expect(backend.codeRequests).to(beEmpty())
                    expect(handler.codeRequests).to(beEmpty())
                    expect(state.accounts).to(beEmpty())
                }
            }

            it("hashes the own delegation indicator in a static call without accessing its target") {
                let backend = MockBackend()
                let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Prague)
                let target = H160(from: [UInt8](repeating: 0x11, count: 20))
                state.setCode(address: address, code: [0xef, 0x01, 0x00] + target.BYTES)
                let handler = StateHandler(state: state)
                let m = Machine(data: [], code: [Opcode.EXTCODEHASH.rawValue], gasLimit: 2600, context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler)
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: Self.delegationHash)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.isStatic()).to(beTrue())
                expect(handler.codeHashRequests).to(equal([address]))
                expect(backend.codeHashRequests).to(beEmpty())
                expect(backend.codeRequests).to(beEmpty())
                expect(m.state.isCold(address: target)).to(beTrue())
            }

            #if TRACING
            it("traces the address, hash and account access gas") {
                let m = TestMachine.machine(opcode: .EXTCODEHASH, gasLimit: 3000)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: .ZERO))
                (m.handler as! TestHandler).codeHashes[address] = hash
                expect(m.stack.push(value: word)).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.data.first?.opcode).to(equal(.EXTCODEHASH))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: hash)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2600))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(400))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(equal([word]))
                expect(m.trace.data.first?.stackIn).to(equal([U256(from: hash)]))
                #endif
            }
            #endif
        }
    }
}
