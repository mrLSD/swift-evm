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
