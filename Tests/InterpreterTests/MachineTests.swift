@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMachineTestsSpec: QuickSpec {
    class CustomHandler: TestHandler {
        var observedStatuses: [Machine.MachineStatus] = []

        override func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
            observedStatuses.append(machine.machineStatus)
            return .OutOfFund
        }
    }

    override class func spec() {
        describe("Machine tests") {
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
