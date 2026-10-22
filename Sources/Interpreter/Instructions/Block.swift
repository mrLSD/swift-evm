import PrimitiveTypes

/// EVM Block instructions
enum BlockInstructions {
    /// Ancestors whose hashes BLOCKHASH can return; EIP-2935 does not widen this window.
    static let BLOCK_HASH_HISTORY = U256(from: 256)

    /// Pushes a hash from the previous `BLOCK_HASH_HISTORY` blocks, or zero outside that window.
    /// A missing hash inside the window is a host failure and ends the machine with `ExitFatal.UnknownBlockHash`.
    static func blockHash(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BLOCKHASH) {
            return
        }

        // Stack size was verified above; this unwrap cannot fail.
        let number = m.stackPop()!
        let currentNumber = m.handler.blockNumber()
        if number < currentNumber && currentNumber - number <= Self.BLOCK_HASH_HISTORY {
            guard let hash = m.handler.blockHash(number: number) else {
                m.machineStatus = .Exit(.Fatal(.UnknownBlockHash))
                return
            }
            m.stackPush(value: U256(from: hash))
        } else {
            m.stackPush(value: U256.ZERO)
        }
    }

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
