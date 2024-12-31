import PrimitiveTypes

/// EVM Stack instructions
enum StackInstructions {
    static func pop(machine m: inout Machine) {
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
    static func push0(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256.ZERO)
    }

    static func push(machine m: inout Machine, n: Int) {
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

    static func swap(machine m: inout Machine, n: Int) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let val1 = m.stackPeek(indexFromTop: 0) else {
            return
        }
        guard let val2 = m.stackPeek(indexFromTop: n) else {
            return
        }

        if case .failure(let err) = m.stack.set(indexFromTop: n, value: val1) {
            m.machineStatus = Machine.MachineStatus.Exit(.Error(err))
            return
        }
        if case .failure(let err) = m.stack.set(indexFromTop: 0, value: val2) {
            m.machineStatus = Machine.MachineStatus.Exit(.Error(err))
            return
        }
    }

    static func dup(machine m: inout Machine, n: Int) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let dupVal = m.stackPeek(indexFromTop: n - 1) else {
            return
        }

        m.stackPush(value: dupVal)
    }
}
