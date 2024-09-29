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
    private(set) var gas: Gas

    /// Current Machine status
    var machineStatus: MachineStatus = .NotStarted

    /// Machine Interpreter handler. User to extend evaluation functinality
    private let handler: InterpreterHandler

    public enum MachineStatus {
        case NotStarted
        case Continue(Int)
        case Jump(Int)
        case Trap(Opcode)
        case Exit(ExitReason)
    }

    public enum ExitReason {
        case Success(ExitSuccess)
        case Revert
        case Error(ExitError)
        case Fatal
    }

    public enum ExitSuccess {
        case Stop
        case Return
    }

    public enum ExitError: Error {
        case StackUnderflow
        case StackOverflow
        case InvalidJump
        case InvalidRange
        case CallTooDeep
        case OutOfOffset
        case OutOfGas
        case OutOfFund
    }

    /// Closure type of Evaluation function.
    /// This function returns `MachineStatus` as result of evaluation
    typealias EvalFunction = (_ m: inout Self) -> ()

    /// Instructions evaluation table. Used to evalueate specific opcodes.
    /// It represent evaluation fuтctions for each existed opcodes. Table initialized with 255 `nil` instructions and filled for each specific `EVM` opcode.
    /// For non-existed opcode the evaluation functions is `nil`.
    private let instructionsEvalTable: [EvalFunction?] = {
        var table = [EvalFunction?](repeating: nil, count: 255)
        table[Int(Opcode.ADD.rawValue)] = ArithmeticInstructions.add
        return table
    }()

    init(data: [UInt8], code: [UInt8], handler: InterpreterHandler) {
        self.data = data
        self.code = code
        self.handler = handler
        self.gas = Gas(limit: 0)
    }

    /// Evaluation loop for `Machine` code.
    /// Return status of evaluation.
    mutating func evalLoop() -> MachineStatus {
        // Evaluation loop
        while true {
            // Ensure that `PC` in code range
            if self.pc < self.code.count {
                self.machineStatus = .Exit(.Success(.Stop))
                break
            }

            // Get Opcode
            guard let op = Opcode(rawValue: self.code[self.pc]) else {
                // TODO: return InvalidOpcode
                self.machineStatus = .Exit(.Success(.Stop))
                break
            }
            // Get evaluation function for opcode
            guard let evalFunc = self.instructionsEvalTable[Int(op.rawValue)] else {
                // TODO: return InvalidOpcode
                self.machineStatus = .Exit(.Success(.Stop))
                break
            }
            // Run evaluation function for Opcode and return status
            evalFunc(&self)
            // Fetch eval status
            switch self.machineStatus {
            // For `Continue` - just increase `pc` by bytes
            case .Continue(let bytes):
                self.pc += bytes
            // For `Jump` = set pc to specific position
            case .Jump(let position):
                self.pc = position
            // For any other status - set `machineStatus` to `evalStatus` and exit from eval loop
            default: {}()
            }
        }
        return self.machineStatus
    }

    /// Evaluate Machine step
    public mutating func step() -> MachineStatus {
        self.evalLoop()
    }

    /// Get `Return` value
    func returnValue() -> [UInt8] {
        self.memory.get(range: self.returnRange)
    }
}
