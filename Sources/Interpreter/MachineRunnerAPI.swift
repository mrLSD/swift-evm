import PrimitiveTypes

// MARK: - Public surface for cross-module test runners
//
// The existing `Machine` initializers and most of its properties are `internal` because
// the module's tests use `@testable import Interpreter`. The `EthereumSpecTests` CLI is
// an executable target — it cannot use `@testable import` — so we expose the minimum
// public surface needed to drive the machine and observe its outcome.
//
// Everything below is purely additive and routes through existing internal members.

public extension Machine {
    /// Public convenience init mirroring the eight-parameter designated initializer.
    convenience init(
        callData: [UInt8],
        code: [UInt8],
        gasLimit: UInt64,
        memoryLimit: Int,
        targetAddress: H160,
        callerAddress: H160,
        callValue: U256,
        handler: InterpreterHandler,
        hardFork: HardFork
    ) {
        self.init(
            data: callData,
            code: code,
            gasLimit: gasLimit,
            memoryLimit: memoryLimit,
            context: Machine.Context(
                targetAddress: targetAddress,
                callerAddress: callerAddress,
                callValue: callValue
            ),
            state: ExecutionState(),
            handler: handler,
            hardFork: hardFork
        )
    }

    /// Drive the machine to termination. Public-facing alias for the internal `evalLoop()`.
    func runUntilExit() {
        self.evalLoop()
    }

    /// Public read-only view of the current machine status. The `MachineStatus` enum is
    /// already `public`, only the property's accessor needs an explicit re-export.
    var status: MachineStatus { self.machineStatus }

    /// Gas remaining at the current point in execution.
    var gasRemaining: UInt64 { self.gas.remaining }

    /// Bytes the machine designated as the call's return value via `RETURN`/`REVERT`.
    /// Returns `[]` if execution did not reach a return-style termination.
    var collectedReturnData: [UInt8] {
        let r = self.returnRange
        guard !r.isEmpty else { return [] }
        return self.memory.get(offset: r.lowerBound, size: r.count)
    }
}
