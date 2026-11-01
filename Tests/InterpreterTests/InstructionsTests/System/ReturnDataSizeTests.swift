@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionReturnDataSizeSpec: QuickSpec {
    override class func spec() {
        describe("Instruction RETURNDATASIZE") {
            it("starts with an empty buffer in both machine initializers") {
                let machines = [
                    TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: 2),
                    TestMachine.machine(opcodes: [.RETURNDATASIZE], gasLimit: 2, memoryLimit: 0, hardFork: .Byzantium)
                ]
                for m in machines {
                    expect(m.returnData.buffer).to(beEmpty())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                    expect(m.stack.data).to(equal([U256.ZERO]))
                    expect(m.gas.remaining).to(equal(0))
                    expect(m.pc).to(equal(1))
                    expect(m.memory.effectiveLength).to(equal(0))
                }
            }

            it("returns the full byte count at the exact gas budget from Byzantium onward") {
                let forks = HardFork.allCases.drop(while: { $0 != .Byzantium })
                expect(forks.first).to(equal(.Byzantium))
                for fork in forks {
                    for size in [0, 1, 31, 32, 33, 255, 256, 257, 4096, 65536] {
                        let m = TestMachine.machine(opcodes: [.RETURNDATASIZE], gasLimit: 2, memoryLimit: 0, hardFork: fork)
                        let buffer = [UInt8](repeating: 0, count: size)
                        m.returnData = Machine.ReturnData(buffer: buffer, length: 2, offset: 17)
                        expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                        let detail = "fork \(fork), buffer size \(size)"

                        m.evalLoop()

                        expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))), description: detail)
                        expect(m.stack.data).to(equal([U256(from: 99), U256(from: UInt64(size))]), description: detail)
                        expect(m.gas.remaining).to(equal(0), description: detail)
                        expect(m.pc).to(equal(1), description: detail)
                        expect(m.memory.effectiveLength).to(equal(0), description: detail)
                        expect(m.gas.memoryGas.gasCost).to(equal(0), description: detail)
                        expect(m.returnData.buffer).to(equal(buffer), description: detail)
                        expect(m.returnData.length).to(equal(2), description: detail)
                        expect(m.returnData.offset).to(equal(17), description: detail)
                    }
                }
            }

            it("rejects every pre-Byzantium fork before checking stack or gas") {
                let forks = HardFork.allCases.prefix(while: { $0 != .Byzantium })
                expect(forks.last).to(equal(.SpuriousDragon))
                for fork in forks {
                    for budget: UInt64 in [0, 1, 2, 10] {
                        for fullStack in [false, true] {
                            let m = TestMachine.machine(opcodes: [.RETURNDATASIZE], gasLimit: budget, memoryLimit: 0, hardFork: fork)
                            m.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 1, offset: 7)
                            if fullStack {
                                for _ in 0 ..< m.stack.limit {
                                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())
                                }
                            }
                            let original = m.stack.data
                            let detail = "fork \(fork), gas \(budget), full stack \(fullStack)"

                            m.evalLoop()

                            expect(m.machineStatus).to(equal(.Exit(.Error(.HardForkNotActive))), description: detail)
                            expect(m.stack.data).to(equal(original), description: detail)
                            expect(m.gas.remaining).to(equal(budget), description: detail)
                            expect(m.pc).to(equal(0), description: detail)
                            expect(m.returnData.buffer).to(equal([1, 2, 3]), description: detail)
                        }
                    }
                }
            }

            it("preserves the stack and return data when gas is insufficient") {
                for budget: UInt64 in [0, 1] {
                    let m = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: budget)
                    m.returnData = Machine.ReturnData(buffer: [0xab, 0, 0xcd], length: 1, offset: 9)
                    expect(m.stack.push(value: U256(from: 99))).to(beSuccess())

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                    expect(m.stack.data).to(equal([U256(from: 99)]))
                    expect(m.gas.remaining).to(equal(budget))
                    expect(m.pc).to(equal(0))
                    expect(m.returnData.buffer).to(equal([0xab, 0, 0xcd]))
                    expect(m.returnData.length).to(equal(1))
                    expect(m.returnData.offset).to(equal(9))
                }
            }

            it("rejects stack overflow before charging gas") {
                for budget: UInt64 in [0, 1, 2, 10] {
                    let m = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: budget)
                    m.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 0, offset: 0)
                    for i in 0 ..< m.stack.limit {
                        expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                    }
                    let original = m.stack.data

                    m.evalLoop()

                    expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                    expect(m.stack.data).to(equal(original))
                    expect(m.gas.remaining).to(equal(budget))
                    expect(m.pc).to(equal(0))
                    expect(m.returnData.buffer).to(equal([1, 2, 3]))
                }
            }

            it("fills the last stack slot without consuming existing values") {
                let m = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: 2)
                m.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 0, offset: 0)
                for i in 0 ..< m.stack.limit - 1 {
                    expect(m.stack.push(value: U256(from: UInt64(i)))).to(beSuccess())
                }
                let original = m.stack.data

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal(original + [U256(from: 3)]))
                expect(m.stack.length).to(equal(m.stack.limit))
                expect(m.gas.remaining).to(equal(0))
            }

            it("reads the supplied buffer after replacement and clearing without caching its size") {
                let m = TestMachine.machine(opcodes: [.RETURNDATASIZE, .RETURNDATASIZE, .RETURNDATASIZE], gasLimit: 6)
                // Supply frame data directly until child-call execution is implemented.
                m.returnData = Machine.ReturnData(buffer: [0xab], length: 0, offset: 0)
                m.step()
                expect(m.machineStatus).to(equal(.Continue))
                expect(m.stack.data).to(equal([U256(from: 1)]))
                expect(m.gas.remaining).to(equal(4))

                m.returnData = Machine.ReturnData(buffer: [0, 0, 0], length: 1, offset: 32)
                m.step()
                expect(m.machineStatus).to(equal(.Continue))
                expect(m.stack.data).to(equal([U256(from: 1), U256(from: 3)]))
                expect(m.gas.remaining).to(equal(2))

                m.returnData = Machine.ReturnData(buffer: [], length: 1, offset: 32)
                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 1), U256(from: 3), U256.ZERO]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.pc).to(equal(3))
            }

            it("keeps return data local to each machine") {
                let first = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: 2)
                let second = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: 2)
                first.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 0, offset: 0)

                first.evalLoop()
                second.evalLoop()

                expect(first.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(second.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(first.stack.data).to(equal([U256(from: 3)]))
                expect(second.stack.data).to(equal([U256.ZERO]))
                expect(first.gas.remaining).to(equal(0))
                expect(second.gas.remaining).to(equal(0))
                expect(second.returnData.buffer).to(beEmpty())
            }

            it("charges every read and stops when a subsequent read cannot be paid") {
                let m = TestMachine.machine(opcodes: [.RETURNDATASIZE, .RETURNDATASIZE], gasLimit: 3)
                m.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 0, offset: 0)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                expect(m.stack.data).to(equal([U256(from: 3)]))
                expect(m.gas.remaining).to(equal(1))
                expect(m.pc).to(equal(1))
                expect(m.returnData.buffer).to(equal([1, 2, 3]))
            }

            it("distinguishes return data from calldata, code, memory and the frame output range") {
                let m = TestMachine.machine(data: [1, 2, 3, 4, 5], opcodes: [.RETURNDATASIZE, .CALLDATASIZE, .CODESIZE, .MSIZE], gasLimit: 11, memoryLimit: 32)
                m.returnData = Machine.ReturnData(buffer: [0xab, 0xcd, 0], length: 1, offset: 7)
                m.returnRange = 8 ..< 15
                expect(m.resizeMemoryAndRecordGas(offset: 0, size: 32)).to(beTrue())
                expect(m.memory.set(offset: 0, value: [0xff], size: 1)).to(beSuccess())
                m.gas.recordRefund(refund: 5)
                let memory = m.memory.get(offset: 0, size: 32)

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 3), U256(from: 5), U256(from: 4), U256(from: 32)]))
                expect(m.gas.remaining).to(equal(0))
                expect(m.gas.refunded).to(equal(5))
                expect(m.gas.memoryGas.gasCost).to(equal(3))
                expect(m.memory.get(offset: 0, size: 32)).to(equal(memory))
                expect(m.memory.effectiveLength).to(equal(32))
                expect(m.returnRange).to(equal(8 ..< 15))
                expect(m.returnData.buffer).to(equal([0xab, 0xcd, 0]))
                expect(m.returnData.length).to(equal(1))
                expect(m.returnData.offset).to(equal(7))
            }

            it("is allowed in a static call") {
                let handler = StaticHandler()
                let m = Machine(data: [], code: [Opcode.RETURNDATASIZE.rawValue], gasLimit: 2, memoryLimit: 0,
                                context: TestMachine.defaultContext(), state: ExecutionState(), handler: handler, hardFork: .Byzantium)
                m.returnData = Machine.ReturnData(buffer: [0, 1, 0], length: 0, offset: 0)
                expect(handler.isStatic()).to(beTrue())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.stack.data).to(equal([U256(from: 3)]))
                expect(m.gas.remaining).to(equal(0))
                expect(handler.logs).to(beEmpty())
            }

            #if TRACING
            it("traces the pushed byte count and instruction cost") {
                let m = TestMachine.machine(opcode: .RETURNDATASIZE, gasLimit: 10)
                m.returnData = Machine.ReturnData(buffer: [1, 2, 3], length: 0, offset: 0)
                m.trace = Trace(config: Trace.Config(callTrace: false, gasCalculation: true, stackInOut: true, hideUnchanged: false, hideMemory: false, hideStack: false, hideStorage: false, storageValueAsHex: false, opcodeAsHex: false), context: Trace.Context(address: H160.ZERO))
                expect(m.stack.push(value: U256(from: 99))).to(beSuccess())

                m.evalLoop()

                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))
                expect(m.trace.beforeEval?.stack?.data).to(equal([U256(from: 99)]))
                expect(m.trace.data.count).to(equal(1))
                expect(m.trace.data.first?.opcode).to(equal(.RETURNDATASIZE))
                expect(m.trace.data.first?.stack?.data).to(equal([U256(from: 99), U256(from: 3)]))
                expect(m.trace.data.first?.tracedGas?.used).to(equal(2))
                expect(m.trace.data.first?.tracedGas?.remaining).to(equal(8))
                #if TRACE_STACK_INOUT
                expect(m.trace.data.first?.stackOut).to(beEmpty())
                expect(m.trace.data.first?.stackIn).to(equal([U256(from: 3)]))
                #endif
            }
            #endif
        }
    }
}
