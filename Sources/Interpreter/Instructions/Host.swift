import PrimitiveTypes

/// EVM Host instructions
enum HostInstructions {
    /// Pushes the balance of the address popped from the machine stack onto the stack.
    /// Calculates and charges gas according to the active hard fork; if the stack top cannot be converted to an address or gas charging fails, the function returns without pushing a value.
    /// - Parameter m: The machine context whose stack, gas recorder, state, and handler are used.
    static func balance(machine m: Machine) {
        guard let address = m.stackPopH256()?.toH160() else {
            return
        }

        // Calculate gas depending on hard fork
        var gasCost: UInt64 = 0
        if m.hardFork.isBerlin() {
            let isCold = m.state.isCold(address: address)
            m.state.warm(address: address, isCold: isCold)
            gasCost = GasCost.warmOrColdCost(isCold: isCold)
        } else if m.hardFork.isIstanbul() {
            // EIP-1884: Repricing for trie-size-dependent opcodes
            gasCost = 700
        } else if m.hardFork.isTangerine() {
            gasCost = 400
        } else {
            gasCost = 20
        }
        if !m.gasRecordCost(cost: gasCost) {
            return
        }

        m.stackPush(value: m.handler.balance(address: address))
    }

    /// Executes the SELFBALANCE host instruction: charges the low gas cost and pushes the balance of the current execution target onto the machine stack.
    /// If the Istanbul hard fork is not active, sets the machine status to Exit(HardForkNotActive) and returns; if gas recording fails, no stack change occurs.
    /// - Parameter m: The machine whose gas, stack, and status are read and updated.
    static func selfbalance(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isIstanbul() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        m.stackPush(value: m.handler.balance(address: m.context.target))
    }
}