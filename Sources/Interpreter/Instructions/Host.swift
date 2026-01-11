import PrimitiveTypes

/// EVM Host instructions
enum HostInstructions {
    /// Pushes the balance of the account at the given address onto the stack.
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

    /// Pushes the balance of the currently executing account onto the stack.
    static func selfBalance(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isIstanbul() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        m.stackPush(value: m.handler.balance(address: m.context.targetAddress))
    }

    /// Pushes the gas price of the transaction onto the stack.
    static func gasPrice(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: m.handler.gasPrice())
    }

    /// Pushes the address of the originator (sender) of the transaction onto the stack.
    static func origin(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = H256(from: m.handler.origin()).BYTES
        m.stackPush(value: U256.fromBigEndian(from: newValue))
    }

    /// EIP-1344: ChainID opcode
    static func chainId(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isIstanbul() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: m.handler.chainId())
    }

    /// Pushes the address of the miner (coinbase) of the current block onto the stack.
    static func coinbase(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = H256(from: m.handler.coinbase()).BYTES
        m.stackPush(value: U256.fromBigEndian(from: newValue))
    }
}
