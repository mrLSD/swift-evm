import PrimitiveTypes

/// Owner of the state that message calls run over. Every rule is selected by `hardFork`, from Frontier
/// onward; there is no separate configuration. The caller keeps `hardFork` consistent with the state's
/// metadata, whose `accessed` data exists from Berlin.
public final class Executor {
    /// EVM call depth limit: 1024
    static let callStackLimit: UInt = 1024
    /// Current substate. `enter`/`exit` keep the object identity, so the reference never changes.
    let state: MemoryState
    /// Hard fork of the whole execution; passed explicitly to every runtime.
    let hardFork: HardFork
    /// Memory limit of every machine created by this executor.
    let memoryLimit: Int

    init(state: MemoryState, hardFork: HardFork, memoryLimit: Int = Int.max) {
        self.state = state
        self.hardFork = hardFork
        self.memoryLimit = memoryLimit
    }

    /// Returns the code for a top-level call, resolving one delegation level from Prague onward.
    /// The delegate is warmed in the current substate; its code is returned without following further delegations.
    ///
    /// - Parameter codeAddress: The account whose code is requested.
    /// - Returns: The account's own code, or the code at its delegation target.
    func authorityCode(codeAddress: H160) -> [UInt8] {
        guard hardFork.isPrague() else {
            return state.code(address: codeAddress)
        }
        switch state.authorityCode(codeAddress) {
        case .Code(let code):
            return code
        case .Delegated(let target):
            state.metadata.accessAddress(target)
            return state.code(address: target)
        }
    }
}
