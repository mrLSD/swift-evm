@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMachineTestsSpec: QuickSpec {
    class CustomHandler: TestHandler {
        override func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
            return .OutOfFund
        }
    }

    override class func spec() {
        describe("Machine tests") {
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

            it("Int or fail tests") {
                let m1 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res1 = m1.getIntOrFail(U256(from: [1, 1, 0, 0]))
                expect(m1.machineStatus).to(equal(.Exit(.Error(.IntOverflow))))
                expect(res1).to(beNil())

                let m2 = TestMachine.machine(opcodes: [], gasLimit: 1)
                let res2 = m2.getIntOrFail(U256(from: 10))
                expect(m2.machineStatus).to(equal(.NotStarted))
                expect(res2).to(equal(10))
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
