import PrimitiveTypes

/// EVM Stack instructions
enum StackInstructions {
    static func pop(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        _ = m.stackPop()
    }

    /// ## Description
    /// Pushes the constant value 0 onto the stack.
    ///
    /// ## EIP
    /// EIP-3855: PUSH0 instruction
    /// https://eips.ethereum.org/EIPS/eip-3855
    static func push0(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256.ZERO)
    }

    static func push(machine m: Machine, n: Int) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        let end = min(m.pc + 1 + n, m.codeSize)
        let slice = m.code[(m.pc + 1) ..< end]
        var val = [UInt8](repeating: 0, count: 32)
        val.replaceSubrange(32 - n ..< 32 - n + slice.count, with: slice)

        let newValue = U256.fromBigEndian(from: val)
        m.machineStatus = Machine.MachineStatus.AddPC(n + 1)
        m.stackPush(value: newValue)
    }

    static func swap(machine m: Machine, n: Int) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let val1 = m.stackPeek(indexFromTop: 0) else {
            return
        }
        guard let val2 = m.stackPeek(indexFromTop: n) else {
            return
        }

        // In that particular case it's impossible to fail `stack.set` operations.
        // As we verified indexes 0 and N for `stack.peek` before.
        _ = m.stack.set(indexFromTop: n, value: val1)
        _ = m.stack.set(indexFromTop: 0, value: val2)
    }

    static func dup(machine m: Machine, n: Int) {
        if !m.verifyStack(pop: n, push: n + 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let dupVal = m.stackPeek(indexFromTop: n - 1) else { return }

        m.stackPush(value: dupVal)
    }
}
