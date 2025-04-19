import PrimitiveTypes

/// EVM Host instructions
enum HostInstructions {
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
