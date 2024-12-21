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
    let data: [UInt8]
    /// Program code.
    let code: [UInt8]
    /// Program counter.
    private(set) var pc: Int = 0
    /// Return value.
    private var returnRange: Range<Int> = 0 ..< 0
    /// A map of valid `jump` destinations.
    private var jumpTable: [Bool] = []
    /// Machine Memory.
    private(set) var memory: Memory = .init(limit: 0)
    /// Machine Stack
    var stack: Stack = .init()
    /// Machine Gasometr
    var gas: Gas
    /// Calculate Code Size
    var codeSize: Int { self.code.count }

    #if TRACING
    /// Tracing data
    var trace: Trace
    #endif

    /// Current Machine status
    var machineStatus: MachineStatus = .NotStarted

    /// Machine Interpreter handler. User to extend evaluation functinality
    private let handler: InterpreterHandler

    public enum MachineStatus: Equatable {
        case NotStarted
        case Continue
        case AddPC(Int)
        case Jump(Int)
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
        case IntOverflow
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
        // Arithmetic
        table[Opcode.ADD.index] = ArithmeticInstructions.add
        table[Opcode.SUB.index] = ArithmeticInstructions.sub
        table[Opcode.MUL.index] = ArithmeticInstructions.mul
        table[Opcode.DIV.index] = ArithmeticInstructions.div
        table[Opcode.MOD.index] = ArithmeticInstructions.rem
        table[Opcode.SDIV.index] = ArithmeticInstructions.sdiv
        table[Opcode.SMOD.index] = ArithmeticInstructions.smod
        table[Opcode.ADDMOD.index] = ArithmeticInstructions.addMod
        table[Opcode.MULMOD.index] = ArithmeticInstructions.mulMod
        table[Opcode.EXP.index] = ArithmeticInstructions.exp
        table[Opcode.SIGNEXTEND.index] = ArithmeticInstructions.signextend

        // BItwise
        table[Opcode.LT.index] = BItwiseInstructions.lt
        table[Opcode.GT.index] = BItwiseInstructions.gt
        table[Opcode.SLT.index] = BItwiseInstructions.slt
        table[Opcode.SGT.index] = BItwiseInstructions.sgt
        table[Opcode.EQ.index] = BItwiseInstructions.eq
        table[Opcode.ISZERO.index] = BItwiseInstructions.isZero
        table[Opcode.AND.index] = BItwiseInstructions.and
        table[Opcode.OR.index] = BItwiseInstructions.or
        table[Opcode.XOR.index] = BItwiseInstructions.xor
        table[Opcode.NOT.index] = BItwiseInstructions.not
        table[Opcode.BYTE.index] = BItwiseInstructions.byte
        table[Opcode.SHL.index] = BItwiseInstructions.shl
        table[Opcode.SHR.index] = BItwiseInstructions.shr
        table[Opcode.SAR.index] = BItwiseInstructions.sar

        // System
        table[Opcode.CODESIZE.index] = SystemInstructions.codeSize

        // Control
        table[Opcode.STOP.index] = ControlInstructions.stop
        table[Opcode.PC.index] = ControlInstructions.pc
        table[Opcode.JUMP.index] = ControlInstructions.jump
        table[Opcode.JUMPI.index] = ControlInstructions.jumpi
        table[Opcode.JUMPDEST.index] = ControlInstructions.jumpDest

        // Stack
        table[Opcode.POP.index] = StackInstructions.pop
        table[Opcode.PUSH0.index] = StackInstructions.push0
        table[Opcode.PUSH1.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 1) }
        table[Opcode.PUSH2.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 2) }
        table[Opcode.PUSH3.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 3) }
        table[Opcode.PUSH4.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 4) }
        table[Opcode.PUSH5.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 5) }
        table[Opcode.PUSH6.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 6) }
        table[Opcode.PUSH7.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 7) }
        table[Opcode.PUSH8.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 8) }
        table[Opcode.PUSH9.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 9) }
        table[Opcode.PUSH10.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 10) }
        table[Opcode.PUSH11.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 11) }
        table[Opcode.PUSH12.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 12) }
        table[Opcode.PUSH13.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 13) }
        table[Opcode.PUSH14.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 14) }
        table[Opcode.PUSH15.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 15) }
        table[Opcode.PUSH16.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 16) }
        table[Opcode.PUSH17.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 17) }
        table[Opcode.PUSH18.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 18) }
        table[Opcode.PUSH19.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 19) }
        table[Opcode.PUSH20.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 20) }
        table[Opcode.PUSH21.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 21) }
        table[Opcode.PUSH22.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 22) }
        table[Opcode.PUSH23.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 23) }
        table[Opcode.PUSH24.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 24) }
        table[Opcode.PUSH25.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 25) }
        table[Opcode.PUSH26.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 26) }
        table[Opcode.PUSH27.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 27) }
        table[Opcode.PUSH28.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 28) }
        table[Opcode.PUSH29.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 29) }
        table[Opcode.PUSH30.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 30) }
        table[Opcode.PUSH31.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 31) }
        table[Opcode.PUSH32.index] = { (_ m: inout Self) in StackInstructions.push(machine: &m, n: 32) }

        table[Opcode.SWAP1.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 1) }
        table[Opcode.SWAP2.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 2) }
        table[Opcode.SWAP3.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 3) }
        table[Opcode.SWAP4.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 4) }
        table[Opcode.SWAP5.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 5) }
        table[Opcode.SWAP6.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 6) }
        table[Opcode.SWAP7.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 7) }
        table[Opcode.SWAP8.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 8) }
        table[Opcode.SWAP9.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 9) }
        table[Opcode.SWAP10.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 10) }
        table[Opcode.SWAP11.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 11) }
        table[Opcode.SWAP12.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 12) }
        table[Opcode.SWAP13.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 13) }
        table[Opcode.SWAP14.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 14) }
        table[Opcode.SWAP15.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 15) }
        table[Opcode.SWAP16.index] = { (_ m: inout Self) in StackInstructions.swap(machine: &m, n: 16) }

        table[Opcode.DUP1.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 1) }
        table[Opcode.DUP2.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 2) }
        table[Opcode.DUP3.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 3) }
        table[Opcode.DUP4.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 4) }
        table[Opcode.DUP5.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 5) }
        table[Opcode.DUP6.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 6) }
        table[Opcode.DUP7.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 7) }
        table[Opcode.DUP8.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 8) }
        table[Opcode.DUP9.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 9) }
        table[Opcode.DUP10.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 10) }
        table[Opcode.DUP11.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 11) }
        table[Opcode.DUP12.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 12) }
        table[Opcode.DUP13.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 13) }
        table[Opcode.DUP14.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 14) }
        table[Opcode.DUP15.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 15) }
        table[Opcode.DUP16.index] = { (_ m: inout Self) in StackInstructions.dup(machine: &m, n: 16) }

        return table
    }()

    init(data: [UInt8], code: [UInt8], gasLimit: UInt64, handler: InterpreterHandler) {
        self.data = data
        self.code = code
        self.jumpTable = Self.analyzeJumpTable(code: code)
        self.handler = handler
        self.gas = Gas(limit: gasLimit)
        #if TRACING
        self.trace = Trace()
        #endif
    }

    /// # Analyze valid jumps
    /// Check is opcode `JUMPDEST` and set `JumpTable` index to  `true`.
    /// For `PUSH` opcodes we increment jump index validation to push index, to avould get PUSH values itself.
    private static func analyzeJumpTable(code: borrowing [UInt8]) -> [Bool] {
        var jumpTable = [Bool](repeating: false, count: code.count)
        var i = 0
        while i < code.count {
            guard let opcode = Opcode(rawValue: code[i]) else {
                i += 1
                continue
            }
            if opcode == Opcode.JUMPDEST {
                jumpTable[i] = true
            } else if let pushIndex = opcode.isPush {
                // Increment PUSH opcode index
                i += pushIndex
            }
            i += 1
        }
        return jumpTable
    }

    /// Check is valid jump destination
    func isValidJumpDestination(at index: Int) -> Bool {
        if index >= self.jumpTable.count {
            return false
        }
        return self.jumpTable[index]
    }

    /// Provide one step for `Machine` execution.
    /// It will change Machine state.
    /// Especially:
    /// - `PC` - program counter for next execution. It can just incremented or set to jump index. PC range: `0..<self.code.count`. When `step` is completed PC incremented (or changed with jump destitations) for the next step opcode processing.
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

        #if TRACING
        self.trace.beforeEval(self, op)
        #endif

        // Run evaluation function for Opcode.
        // NOTE: It can change `MachineStatus` or `PC`
        evalFunc(&self)

        // Change `PC` for the next step
        switch self.machineStatus {
        case .AddPC(let add):
            self.pc += add
            self.machineStatus = .Continue
        case .Jump(let jumpPC):
            self.pc = jumpPC
            self.machineStatus = .Continue
        case .Continue:
            self.pc += 1
        default: ()
        }

        #if TRACING
        self.trace.afterEval(self).complete()
        #endif
    }

    /// Evaluation loop for `Machine` code.
    /// Return status of evaluation.
    mutating func evalLoop() {
        // Set `MachineStatus` to `Continue` to start evaluation.
        self.machineStatus = MachineStatus.Continue
        // Evaluation loop
        while self.machineStatus == MachineStatus.Continue {
            self.step()
        }
    }

    // TODO: refactore it
//    /// Get `Return` value
//    func returnValue() -> [UInt8] {
//        self.memory.get(range: self.returnRange)
//    }
}
