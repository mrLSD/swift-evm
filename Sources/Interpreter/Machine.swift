import PrimitiveTypes

/// Interpreter handler used to pass Handler functions to Interpreter to
/// extend functionality for specific needs
public protocol InterpreterHandler {
    /// Run function before `Opcode` execution in evaluation stage in Machine
    func beforeOpcodeExecution(machine: inout Machine, opcode: Opcode, address: H160) -> Machine
        .ExitError?
}

/// Machine represents EVM core execution layer
public struct Machine {
    /// Program data
    private let data: [UInt8]
    /// Program code.
    private let code: [UInt8]
    /// Program counter.
    private var pc: Int = 0
    /// Return value.
    private var returnRange: Range<Int> = 0 ..< 0
    /// Code validity maps.
    private let valids: [UInt8] = []
    /// Machine Memory.
    private var memory: Memory = .init(limit: 0)
    /// Machine Stack
    var stack: Stack = .init()
    /// Machine Gasometr
    var gas: Gas

    /// Current Machine status
    var machineStatus: MachineStatus = .NotStarted

    /// Machine Interpreter handler. User to extend evaluation functinality
    private let handler: InterpreterHandler

    public enum MachineStatus: Equatable {
        case NotStarted
        case Continue
        case Jump(Int)
        case Trap(Opcode)
        case Exit(ExitReason)
    }

    public enum ExitReason: Equatable {
        case Success(ExitSuccess)
        case Revert
        case Error(ExitError)
        case Fatal
    }

    public enum ExitSuccess: Equatable {
        case Stop
        case Return
    }

    public enum ExitError: Equatable, Error {
        case StackUnderflow
        case StackOverflow
        case InvalidJump
        case InvalidRange
        case CallTooDeep
        case OutOfOffset
        case OutOfGas
        case OutOfFund
        case InvalidOpcode(UInt8)
    }

    /// Closure type of Evaluation function.
    /// This function returns `MachineStatus` as result of evaluation
    typealias EvalFunction = (_ m: inout Self) -> ()

    /// Instructions evaluation table. Used to evaluate specific opcodes.
    /// It represent evaluation functions for each existed opcodes. Table initialized with 255 `nil` instructions and filled for each specific `EVM` opcode.
    /// For non-existed opcode the evaluation functions is `nil`.
    private let instructionsEvalTable: [EvalFunction?] = {
        var table = [EvalFunction?](repeating: nil, count: 255)
        table[Opcode.ADD.index] = ArithmeticInstructions.add
        table[Opcode.SUB.index] = ArithmeticInstructions.sub
        table[Opcode.MUL.index] = ArithmeticInstructions.mul
        return table
    }()

    init(data: [UInt8], code: [UInt8], gasLimit: UInt64, handler: InterpreterHandler) {
        self.data = data
        self.code = code
        self.handler = handler
        self.gas = Gas(limit: gasLimit)
    }

    /// Provide one step for `Machine` execution.
    /// It will change Machine state.
    /// Especially:
    /// - `PC` - program counter for next execution. It can just incremented or set to jump index
    /// - `machineStatus` - during evaluation can be changed, for example contain result of `ExitReason`
    mutating func step() {
        // Ensure that `PC` in code range, otherwise indicate `sTOP` execution.
        if self.pc >= self.code.count {
            self.machineStatus = .Exit(.Success(.Stop))
            return
        }
        // Get Opcode
        let opcodeNum = self.code[self.pc]
        guard let op = Opcode(rawValue: opcodeNum), let evalFunc = self.instructionsEvalTable[op.index] else {
            self.machineStatus = MachineStatus.Exit(ExitReason.Error(ExitError.InvalidOpcode(opcodeNum)))
            return
        }
        // Increment `PC` for the next step
        self.pc += 1
        // Run evaluation function for Opcode.
        // NOTE: It can change `MachineStatus` or `PC`
        evalFunc(&self)
    }

    /// Evaluation loop for `Machine` code.
    /// Return status of evaluation.
    mutating func evalLoop() {
        // Set `MachineStatus` to `Continue` to start evaluation.
        self.machineStatus = MachineStatus.Continue
        // Evaluation loop
        while case MachineStatus.Continue = self.machineStatus {
            self.step()
        }
    }

    // Get `Return` value
//    func returnValue() -> [UInt8] {
//        self.memory.get(range: self.returnRange)
//    }
}
