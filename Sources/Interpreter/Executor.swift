/// Executor for running the runtime machines
public final class Executor {
    /// Execution state of the executor
    var state: ExecutionState
    /// Runtime machines stack
    var runtime: [Machine] = []

    /// Initialize executor with execution state
    public init(state: ExecutionState) {
        self.state = state
    }

    /// Execute instructions until halt
    public func execute() {}
}
