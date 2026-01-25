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
        }
    }
}
