import PrimitiveTypes

/// Core EVM execution engine.
///
/// `Machine` owns the mutable state required to interpret EVM bytecode, including the program
/// counter, stack, memory, gas accounting, return data, and execution context. It precomputes a
/// jump destination table for validating `JUMP` `JUMPI` targets and uses an opcode dispatch table
/// to evaluate instructions.
///
/// Execution is driven via `step()` for single-instruction progress or `evalLoop()` to run until
/// termination. Progress and termination are communicated through `machineStatus`, with stop
/// reasons expressed by `ExitReason`.
///
/// - Note: Opcode semantics can depend on `hardFork`, which gates feature availability and
/// behavior differences across protocol revisions.
public final class Machine {
    /// Program input data
    let data: [UInt8]
    /// Program code.
    let code: [UInt8]
    /// Program counter.
    private(set) var pc: Int = 0
    /// Return range for `RETURN` and `REVERT`.
    var returnRange: Range<Int> = 0 ..< 0
    /// A map of valid `jump` destinations.
    private var jumpTable: [Bool] = []
    /// Machine Memory.
    private(set) var memory: Memory = .init()
    /// Machine Stack
    var stack: Stack = .init()
    /// Machine Gasometr
    var gas: Gas
    /// Calculate Code Size
    var codeSize: Int { self.code.count }
    /// EVM  hard fork
    let hardFork: HardFork
    /// EVM return data
    var returnData: ReturnData
    /// EVM execution context
    var context: Context
    /// EVM execution state
    var state: ExecutionState

    #if TRACING
    /// Tracing data
    var trace: Trace
    #endif

    /// Current Machine status
    var machineStatus: MachineStatus = .NotStarted

    /// Machine Interpreter handler. Used to extend evaluation functionality
    let handler: InterpreterHandler

    /// Machine return data
    public struct ReturnData {
        let buffer: [UInt8]
        let length: Int
        let offset: Int
    }

    /// Machine EVM Context
    public struct Context {
        /// Execution target address
        let targetAddress: H160
        /// Sender (caller) address
        let callerAddress: H160
        /// EVM apparent value (Value of the call)
        let callValue: U256
    }

    /// Represents the current state of the EVM execution loop.
    ///
    /// `MachineStatus` is used as a lightweight control channel between opcode evaluation
    /// and the main stepping logic. Most opcodes leave the machine in `.Continue`, while
    /// control-flow opcodes can request a program counter update (`.AddPC` / `.Jump`) and
    /// terminating opcodes set `.Exit` with an `ExitReason`.
    @frozen
    public enum MachineStatus: Equatable {
        case NotStarted
        case Continue
        case AddPC(Int)
        case Jump(Int)
        case Exit(ExitReason)
    }

    /// Describes why the machine stopped executing.
    ///
    /// EVM execution terminates in one of four broad categories:
    /// - successful completion (`.Success`),
    /// - a non-fatal rollback (`.Revert`),
    /// - a recoverable error (`.Error`), or
    /// - a fatal error (`.Fatal`) when the interpreter can no longer proceed.
    @frozen
    public enum ExitReason: Equatable, Error {
        case Success(ExitSuccess)
        case Revert
        case Error(ExitError)
        case Fatal(ExitFatal)
    }

    /// Indicates a successful termination condition.

    @frozen
    public enum ExitSuccess: Equatable, Error {
        case Stop
        case Return
    }

    /// Indicates an unrecoverable interpreter failure.
    ///
    /// Fatal errors represent situations where the interpreter cannot reliably continue,
    /// even to produce a standard EVM error. They are treated separately from `ExitError`.
    @frozen
    public enum ExitFatal: Equatable, Error {
        case ReadMemory
    }

    /// Errors produced by memory-related operations.
    ///
    /// These cases usually correspond to violations of configured limits (for example,
    /// memory growth/copy limits) or invalid ranges/offsets when copying input data.
    @frozen
    public enum MemoryError: Equatable, Error {
        case SetLimitExceeded
        case CopyLimitExceeded
        case CopyDataOffsetOutOfBounds
        case CopyDataLimitExceeded
    }

    /// Errors produced during opcode execution.
    ///
    /// These failures correspond to standard EVM exceptional halts (for example stack
    /// underflow/overflow, invalid jump destinations, out-of-gas) as well as interpreter
    /// validation errors (invalid opcode, hard fork gating, or range/overflow issues).
    ///
    /// Some cases wrap a more specific domain error, such as `MemoryError`.
    @frozen
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
        case MemoryOperation(MemoryError)
        case HardForkNotActive
    }

    /// Closure type of Evaluation function.
    /// This function returns `MachineStatus` as result of evaluation
    typealias EvalFunction = (_ m: Machine) -> Void

    /// Instructions evaluation table. Used to evaluate specific opcodes.
    /// It represent evaluation functions for each existed opcodes. Table initialized with 256 `nil` instructions and filled for each specific `EVM` opcode.
    /// For non-existed opcode the evaluation functions is `nil`.
    private let instructionsEvalTable: [EvalFunction?] = {
        var table = [EvalFunction?](repeating: nil, count: 256)
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

        // Bitwise
        table[Opcode.LT.index] = BitwiseInstructions.lt
        table[Opcode.GT.index] = BitwiseInstructions.gt
        table[Opcode.SLT.index] = BitwiseInstructions.slt
        table[Opcode.SGT.index] = BitwiseInstructions.sgt
        table[Opcode.EQ.index] = BitwiseInstructions.eq
        table[Opcode.ISZERO.index] = BitwiseInstructions.isZero
        table[Opcode.AND.index] = BitwiseInstructions.and
        table[Opcode.OR.index] = BitwiseInstructions.or
        table[Opcode.XOR.index] = BitwiseInstructions.xor
        table[Opcode.NOT.index] = BitwiseInstructions.not
        table[Opcode.BYTE.index] = BitwiseInstructions.byte
        table[Opcode.SHL.index] = BitwiseInstructions.shl
        table[Opcode.SHR.index] = BitwiseInstructions.shr
        table[Opcode.SAR.index] = BitwiseInstructions.sar

        // System
        table[Opcode.CODESIZE.index] = SystemInstructions.codeSize
        table[Opcode.CODECOPY.index] = SystemInstructions.codeCopy
        table[Opcode.CALLDATASIZE.index] = SystemInstructions.callDataSize
        table[Opcode.CALLDATACOPY.index] = SystemInstructions.callDataCopy
        table[Opcode.CALLDATALOAD.index] = SystemInstructions.callDataLoad
        table[Opcode.CALLVALUE.index] = SystemInstructions.callValue
        table[Opcode.ADDRESS.index] = SystemInstructions.address
        table[Opcode.CALLER.index] = SystemInstructions.caller
        table[Opcode.SHA3.index] = SystemInstructions.keccak256

        // Control
        table[Opcode.STOP.index] = ControlInstructions.stop
        table[Opcode.PC.index] = ControlInstructions.pc
        table[Opcode.JUMP.index] = ControlInstructions.jump
        table[Opcode.JUMPI.index] = ControlInstructions.jumpi
        table[Opcode.JUMPDEST.index] = ControlInstructions.jumpDest
        table[Opcode.RETURN.index] = ControlInstructions.ret
        table[Opcode.REVERT.index] = ControlInstructions.revert

        // Stack
        table[Opcode.POP.index] = StackInstructions.pop
        table[Opcode.PUSH0.index] = StackInstructions.push0
        table[Opcode.PUSH1.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 1) }
        table[Opcode.PUSH2.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 2) }
        table[Opcode.PUSH3.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 3) }
        table[Opcode.PUSH4.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 4) }
        table[Opcode.PUSH5.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 5) }
        table[Opcode.PUSH6.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 6) }
        table[Opcode.PUSH7.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 7) }
        table[Opcode.PUSH8.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 8) }
        table[Opcode.PUSH9.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 9) }
        table[Opcode.PUSH10.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 10) }
        table[Opcode.PUSH11.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 11) }
        table[Opcode.PUSH12.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 12) }
        table[Opcode.PUSH13.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 13) }
        table[Opcode.PUSH14.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 14) }
        table[Opcode.PUSH15.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 15) }
        table[Opcode.PUSH16.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 16) }
        table[Opcode.PUSH17.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 17) }
        table[Opcode.PUSH18.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 18) }
        table[Opcode.PUSH19.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 19) }
        table[Opcode.PUSH20.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 20) }
        table[Opcode.PUSH21.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 21) }
        table[Opcode.PUSH22.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 22) }
        table[Opcode.PUSH23.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 23) }
        table[Opcode.PUSH24.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 24) }
        table[Opcode.PUSH25.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 25) }
        table[Opcode.PUSH26.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 26) }
        table[Opcode.PUSH27.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 27) }
        table[Opcode.PUSH28.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 28) }
        table[Opcode.PUSH29.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 29) }
        table[Opcode.PUSH30.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 30) }
        table[Opcode.PUSH31.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 31) }
        table[Opcode.PUSH32.index] = { (_ m: Machine) in StackInstructions.push(machine: m, n: 32) }

        table[Opcode.SWAP1.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 1) }
        table[Opcode.SWAP2.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 2) }
        table[Opcode.SWAP3.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 3) }
        table[Opcode.SWAP4.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 4) }
        table[Opcode.SWAP5.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 5) }
        table[Opcode.SWAP6.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 6) }
        table[Opcode.SWAP7.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 7) }
        table[Opcode.SWAP8.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 8) }
        table[Opcode.SWAP9.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 9) }
        table[Opcode.SWAP10.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 10) }
        table[Opcode.SWAP11.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 11) }
        table[Opcode.SWAP12.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 12) }
        table[Opcode.SWAP13.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 13) }
        table[Opcode.SWAP14.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 14) }
        table[Opcode.SWAP15.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 15) }
        table[Opcode.SWAP16.index] = { (_ m: Machine) in StackInstructions.swap(machine: m, n: 16) }

        table[Opcode.DUP1.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 1) }
        table[Opcode.DUP2.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 2) }
        table[Opcode.DUP3.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 3) }
        table[Opcode.DUP4.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 4) }
        table[Opcode.DUP5.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 5) }
        table[Opcode.DUP6.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 6) }
        table[Opcode.DUP7.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 7) }
        table[Opcode.DUP8.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 8) }
        table[Opcode.DUP9.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 9) }
        table[Opcode.DUP10.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 10) }
        table[Opcode.DUP11.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 11) }
        table[Opcode.DUP12.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 12) }
        table[Opcode.DUP13.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 13) }
        table[Opcode.DUP14.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 14) }
        table[Opcode.DUP15.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 15) }
        table[Opcode.DUP16.index] = { (_ m: Machine) in StackInstructions.dup(machine: m, n: 16) }

        // Memory
        table[Opcode.MLOAD.index] = MemoryInstructions.mload
        table[Opcode.MSTORE.index] = MemoryInstructions.mstore
        table[Opcode.MSTORE8.index] = MemoryInstructions.mstore8
        table[Opcode.MSIZE.index] = MemoryInstructions.msize

        // Host
        table[Opcode.BALANCE.index] = HostInstructions.balance
        table[Opcode.SELFBALANCE.index] = HostInstructions.selfBalance
        table[Opcode.GASPRICE.index] = HostInstructions.gasPrice
        table[Opcode.ORIGIN.index] = HostInstructions.origin
        table[Opcode.CHAINID.index] = HostInstructions.chainId
        table[Opcode.COINBASE.index] = HostInstructions.coinbase

        return table
    }()

    /// Creates a new EVM `Machine` configured for executing `code` with the provided input and environment.
    ///
    /// This initializer builds the jump destination table from `code`, initializes gas tracking with
    /// `gasLimit`, and sets the default hard fork to the latest supported revision. `returnData` starts
    /// empty and the program counter is positioned at the beginning of the bytecode.
    ///
    /// - Parameters:
    ///   - data: Call data (input) available to the program during execution.
    ///   - code: EVM bytecode to execute.
    ///   - gasLimit: Maximum amount of gas available for this execution.
    ///   - context: Execution context, such as caller/target addresses and call value.
    ///   - state: Mutable execution state used by opcodes (e.g., for host interactions).
    ///   - handler: Hook provider invoked before opcode execution to extend/intercept behavior.
    init(data: [UInt8], code: [UInt8], gasLimit: UInt64, context: Context, state: ExecutionState, handler: InterpreterHandler) {
        self.data = data
        self.code = code
        self.jumpTable = Self.analyzeJumpTable(code: code)
        self.context = context
        self.returnData = ReturnData(buffer: [], length: 0, offset: 0)
        self.handler = handler
        self.state = state
        self.gas = Gas(limit: gasLimit)
        self.hardFork = HardFork.latest()
        #if TRACING
        self.trace = Trace()
        #endif
    }

    /// Creates a new EVM `Machine` with explicit resource limits and a specified hard fork.
    ///
    /// Use this initializer when you need to control memory growth via `memoryLimit` and/or run
    /// execution under a particular `hardFork` revision. The jump destination table is derived
    /// from `code`, gas accounting is initialized with `gasLimit`, and `returnData` starts empty.
    ///
    /// - Parameters:
    ///   - data: Call data (input) available to the program during execution.
    ///   - code: EVM bytecode to execute.
    ///   - gasLimit: Maximum amount of gas available for this execution.
    ///   - memoryLimit: Upper bound for memory growth used by `Memory` to enforce limits.
    ///   - context: Execution context, such as caller/target addresses and call value.
    ///   - state: Mutable execution state used by opcodes (e.g., for host interactions).
    ///   - handler: Hook provider invoked before opcode execution to extend/intercept behavior.
    ///   - hardFork: Hard fork ruleset that gates opcode semantics and feature availability.
    init(data: [UInt8], code: [UInt8], gasLimit: UInt64, memoryLimit: Int, context: Context, state: ExecutionState, handler: InterpreterHandler, hardFork: HardFork) {
        self.data = data
        self.code = code
        self.jumpTable = Self.analyzeJumpTable(code: code)
        self.context = context
        self.returnData = ReturnData(buffer: [], length: 0, offset: 0)
        self.handler = handler
        self.state = state
        self.gas = Gas(limit: gasLimit)
        self.memory = Memory(limit: memoryLimit)
        self.hardFork = hardFork
        #if TRACING
        self.trace = Trace()
        #endif
    }

    /// # Analyze valid jumps
    /// Check is opcode `JUMPDEST` and set `JumpTable` index to  `true`.
    /// For `PUSH` opcodes we increment jump index validation to push index, to avoid getting PUSH values themselves.
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
    @inline(__always)
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
    func step() {
        // Ensure that `PC` in code range, otherwise indicate `sTOP` execution.
        if self.pc >= self.code.count {
            self.machineStatus = .Exit(.Success(.Stop))
            return
        }
        // Get Opcode
        let opcodeNum = self.code[self.pc]
        let rawOp = Opcode(rawValue: opcodeNum)

        // Handler before code execution from the host environment.
        // Pre-processing of opcodes before their execution. This allows for injecting custom logic
        // into the behavior of opcodes and the EVM as a whole
        if let err = self.handler.beforeOpcodeExecution(machine: self, opcode: rawOp) {
            self.machineStatus = MachineStatus.Exit(ExitReason.Error(err))
            return
        }

        // Evaluate opcode instruction
        guard let op = rawOp, let evalFunc = self.instructionsEvalTable[op.index] else {
            self.machineStatus = MachineStatus.Exit(ExitReason.Error(ExitError.InvalidOpcode(opcodeNum)))
            return
        }

        #if TRACING
        self.trace.beforeEval(self, op)
        #endif

        // Run evaluation function for Opcode.
        // NOTE: It can change `MachineStatus` or `PC`
        evalFunc(self)

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
    func evalLoop() {
        // Set `MachineStatus` to `Continue` to start evaluation.
        self.machineStatus = MachineStatus.Continue
        // Evaluation loop
        while self.machineStatus == MachineStatus.Continue {
            self.step()
        }
    }

    // MARK: - Stack Verification Wrappers

    /// Verifies if the stack has enough elements for a `pop` operation.
    /// Updates `machineStatus` to `.Exit(.Error(.StackUnderflow))` on failure.
    ///
    /// - Parameter pop: Number of elements to pop.
    /// - Returns: `true` if verification passed, `false` otherwise.
    @inline(__always)
    func verifyStack(pop: Int) -> Bool {
        switch self.stack.verifyStack(pop: pop) {
        case .success:
            return true
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return false
        }
    }

    /// Verifies if the stack can handle a `pop` and `push` operation sequence.
    /// Updates `machineStatus` to `.Exit(.Error(...))` on failure (Underflow or Overflow).
    ///
    /// - Parameters:
    ///   - pop: Number of elements to pop.
    ///   - push: Number of elements to push.
    /// - Returns: `true` if verification passed, `false` otherwise.
    @inline(__always)
    func verifyStack(pop: Int, push: Int) -> Bool {
        switch self.stack.verifyStack(pop: pop, push: push) {
        case .success:
            return true
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return false
        }
    }

    // MARK: - Stack Operations Wrappers

    /// Wrapper for `MachineStack` pop operation. If `pop` operation fails, set
    /// `machineStatus` exit error status.
    ///
    /// - Returns: Optional value
    func stackPop() -> U256? {
        switch self.stack.pop() {
        case .success(let value):
            return value
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return nil
        }
    }

    /// Wrapper for `MachineStack` pop H256 operation. If `popH256` operation fails, set
    /// `machineStatus` exit error status.
    ///
    /// - Returns: Optional value
    func stackPopH256() -> H256? {
        switch self.stack.popH256() {
        case .success(let value):
            return value
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return nil
        }
    }

    /// Wrapper for `MachineStack` push operation. If `push` operation fails, set
    /// `machineStatus` exit error status.
    func stackPush(value: U256) {
        switch self.stack.push(value: value) {
        case .success:
            return
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return
        }
    }

    /// Wrapper for `MachineStack` peek operation. If `peek` operation fails, set
    /// `machineStatus` exit error status.
    ///
    /// - Returns: Boolean value is operation success or not
    func stackPeek(indexFromTop: Int) -> U256? {
        switch self.stack.peek(indexFromTop: indexFromTop) {
        case .success(let val):
            return val
        case .failure(let err):
            self.machineStatus = .Exit(.Error(err))
            return nil
        }
    }

    // MARK: - Gas & Memory Operations

    /// Wrapper for `Machine` gas `recordCost` operation. If operation fails, set
    /// `machineStatus` exit error `OutOfGas`.
    ///
    /// - Returns: Boolean value is operation success or not
    @inline(__always)
    func gasRecordCost(cost: UInt64) -> Bool {
        if !self.gas.recordCost(cost: cost) {
            self.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
            return false
        }
        return true
    }

    /// Resizes the memory block and records the gas cost for the resizing operation.
    ///
    /// This function calculates the gas cost associated with resizing the memory using the provided
    /// offset and size. If the gas cost calculation is successful, it records the cost; otherwise,
    /// it updates the machine status with the corresponding error and returns false.
    ///
    /// - Parameters:
    ///   - offset: The starting offset from which the memory should be resized.
    ///   - size: The new size to which the memory should be resized.
    /// - Returns: A Boolean value indicating whether the memory was successfully resized and the gas cost recorded.
    func resizeMemoryAndRecordGas(offset: Int, size: Int) -> Bool {
        // Calculate the gas cost for resizing memory.
        let resizeMemoryCost = self.gas.memoryGas.resize(end: offset, length: size)
        switch resizeMemoryCost {
        case .success(let resizeMemory):
            // If memory gas cost changed - record cost and resize memory itself
            if case .Resized(let resizeMemoryCost) = resizeMemory {
                guard self.gasRecordCost(cost: resizeMemoryCost) else {
                    return false
                }
                // Attempt to resize the memory block using the specified `offset` and `size`.
                // Although previous validations ensure that the parameters are correct and prevent common errors,
                // there remains a impossibility that an unexpected condition causes the resize function to return `false`.
                // To handle this edge case safely, we perform an additional check on the return value anyway.
                // If the memory resize `fails`, we update the machine's status to exit with an `OutOfGas` error,
                // thereby ensuring that the machine stops execution in a controlled manner.
                //
                // NOTE: This guard statement is written as a one-line expression to facilitate test coverage,
                // even though the failure scenario is highly unlikely (for example memory I/O crash).
                guard self.memory.resize(offset: offset, size: size) else { self.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return false }
            }
        case .failure(let err):
            self.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(err))
            return false
        }

        return true
    }

    /// Get `Int` from `U256`. If fails return `nil` and set `Machine` status error to `IntOverflow`.
    ///
    /// - Parameters:
    ///   - value: `U256` for converting
    /// - Returns: optional `UInt` value
    func getIntOrFail(_ value: U256) -> Int? {
        guard let intValue = value.getInt else {
            self.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.IntOverflow))
            return nil
        }
        return intValue
    }
}
