import PrimitiveTypes

/// EVM Block instructions
enum BlockInstructions {
    /// Pushes the current block's Unix timestamp in seconds onto the stack.
    static func timestamp(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: m.handler.blockTimestamp())
    }

    /// Pushes the current block's number onto the stack.
    static func number(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: m.handler.blockNumber())
    }

    /// EIP-4399: pushes difficulty before Paris, or PREVRANDAO from Paris onward.
    static func prevrandao(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        if m.hardFork.isParis() {
            guard let randomness = m.handler.blockRandomness() else {
                preconditionFailure("PREVRANDAO requires block randomness from Paris")
            }
            m.stackPush(value: U256(from: randomness))
        } else {
            m.stackPush(value: m.handler.blockDifficulty())
        }
    }

    /// Pushes the gas limit of the current block onto the stack.
    static func gasLimit(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: m.handler.blockGasLimit())
    }
}
