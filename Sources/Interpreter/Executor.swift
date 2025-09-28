public final class Executor {
    var state: ExecutionState
    var runtime: [Machine] = []

    init(state: ExecutionState) {
        self.state = state
    }

    public func execute() {}
}
