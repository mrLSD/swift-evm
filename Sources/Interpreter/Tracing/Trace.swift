#if TRACING

import PrimitiveTypes

/// Current state of execution collected in `TraceData`

/// ## Tracing DEFINE options
/// - `TRACE_CALL_TRACE` - Collect `sub-call` trace data as a tree
/// -  `TRACE_GAS_CALC`
/// - `TRACE_STACK_INOUT`
/// - `TRACE_HIDE_UNCHANGED`
/// - `TRACE_HI`DE_MEMORY`
/// - `TRACE_HIDE_STACK`
/// - `TRACE_HIDE_STORAGE`
/// - `TRACE_STORAGE_HEX_VALUE`
/// - `TRACE_OPCODE_HEX_VALUE`
public class Trace {
    /// Tracing configuration
    public struct Config {
        /// Collect `sub-call` trace data as a tree
        let callTrace: Bool
        /// Collect additional details about gas calculation
        let gasCalculation: Bool
        /// Show Stack In/Out information if Stack was changed
        let stackInOut: Bool
        /// Hide unchanged `Stack` and `Memory`
        let hideUnchanged: Bool
        /// Hide `Memory` data
        let hideMemory: Bool
        /// Hide `Stack` data
        let hideStack: Bool
        /// Hide Storage data
        let hideStorage: Bool
        /// Show `Storage` value as hex integer
        let storageValueAsHex: Bool
        /// Show `Opcode` as hex integer
        let opcodeAsHex: Bool

        init(callTrace: Bool, gasCalculation: Bool, stackInOut: Bool, hideUnchanged: Bool, hideMemory: Bool, hideStack: Bool, hideStorage: Bool, storageValueAsHex: Bool, opcodeAsHex: Bool) {
            self.callTrace = callTrace
            self.gasCalculation = gasCalculation
            self.stackInOut = stackInOut
            self.hideUnchanged = hideUnchanged
            self.hideMemory = hideMemory
            self.hideStack = hideStack
            self.hideStorage = hideStorage
            self.storageValueAsHex = storageValueAsHex
            self.opcodeAsHex = opcodeAsHex
        }

        /// Init config from `DEFINE` options
        init() {
            #if TRACE_CALL_TRACE
            self.callTrace = true
            #else
            self.callTrace = false
            #endif

            #if TRACE_GAS_CALC
            self.gasCalculation = true
            #else
            self.gasCalculation = false
            #endif

            #if TRACE_STACK_INOUT
            self.stackInOut = true
            #else
            self.stackInOut = false
            #endif

            #if TRACE_HIDE_UNCHANGED
            self.hideUnchanged = true
            #else
            self.hideUnchanged = false
            #endif

            #if TRACE_HIDE_MEMORY
            self.hideMemory = true
            #else
            self.hideMemory = false
            #endif

            #if TRACE_HIDE_STACK
            self.hideStack = true
            #else
            self.hideStack = false
            #endif

            #if TRACE_HIDE_STORAGE
            self.hideStorage = true
            #else
            self.hideStorage = false
            #endif

            #if TRACE_STORAGE_HEX_VALUE
            self.storageValueAsHex = true
            #else
            self.storageValueAsHex = false
            #endif

            #if TRACE_OPCODE_HEX_VALUE
            self.opcodeAsHex = true
            #else
            self.opcodeAsHex = false
            #endif
        }
    }

    /// Trace data
    public class TraceData {
        /// Current PC
        private(set) var pc: Int
        /// Current `Opcode`
        private(set) var opcode: Opcode
        private(set) var depth: Int
        /// Current `Memory`
        private(set) var memory: Memory?
        /// Current  `Stack`
        private(set) var stack: Stack?
        /// Current `Gas`
        private(set) var gas: Gas
        /// Stack In data for current step
        private(set) var stackIn: [U256]?
        /// Stack Out data for current step
        private(set) var stackOut: [U256]?
        /// Storage data for current contract
        private(set) var storage: [U256: U256]?
        /// Sub call traces for tree representation. It should be enabled with `Config.callTrace`
        private(set) var subCallTrace: [TraceData]?

        init(_ machine: borrowing Machine, _ opcode: Opcode, _ cfg: Config) {
            self.pc = machine.pc
            self.gas = machine.gas
            self.opcode = opcode
            self.depth = 1
            if cfg.hideStack {
                self.stack = nil
            } else {
                self.stack = machine.stack
            }
            self.stackIn = nil
            self.stackOut = nil
            self.memory = machine.memory
            self.storage = nil
            self.subCallTrace = nil
        }
    }

    /// Trace data gathering context - details about current contract
    public struct Context {
        let address: H160

        init(address: H160) {
            self.address = address
        }
    }

    /// Tracing config
    let config: Config
    /// Current contract context
    let context: Context?
    /// Tracing data
    var data: [TraceData] = []
    var current: TraceData?

    init() {
        self.config = Config()
        self.context = nil
    }

    init(config: Config, context: Context) {
        self.config = config
        self.context = context
    }

    /// Trace step before Machine opcode evaluation
    func beforeEval(_ machine: borrowing Machine, _ op: Opcode) {
        self.current = TraceData(machine, op, self.config)
    }

    /// Trace step after Machine opcode evaluation.
    func afterEval(_ machine: borrowing Machine) -> Self {
        return self
    }

    /// Complete tracing behavior's for current step
    func complete() {
        guard let currentTrace = self.current else { return }
        self.data.append(currentTrace)
    }

    /// Print Trace ouptut
    func printOutput() {
        print("\nTrace:\n")
        for trace in self.data {
            print("\tPC: \(trace.pc)")
            print("\t\(trace.opcode.name)")
            print("\t\(trace.gas)")
            print("\t\(trace.stack)")
        }
    }
}

#endif
