import PrimitiveTypes

/// EVM Stack instructions
enum StackInstructions {
    static func pop(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            _ = try m.stack.pop().get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    /// ## Description
    /// Pushes the constant value 0 onto the stack.
    ///
    /// ## EIP
    /// EIP-3855: PUSH0 instruction
    /// https://eips.ethereum.org/EIPS/eip-3855
    static func push0(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            try m.stack.push(value: U256.ZERO).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func push(machine m: inout Machine, n: Int) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let end = min(m.pc + 1 + n, m.codeSize)
            let slice = m.code[(m.pc + 1) ..< end]
            var val = [UInt8](repeating: 0, count: 32)
            val.replaceSubrange(32 - n ..< 32 - n + slice.count, with: slice)

            let newValue = U256.fromBigEndian(from: val)
            m.machineStatus = Machine.MachineStatus.AddPC(n + 1)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func swap(machine m: inout Machine, n: Int) {
        do {
            let val1 = try m.stack.peek(indexFromTop: 0).get()
            let val2 = try m.stack.peek(indexFromTop: n).get()

            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            try m.stack.set(indexFromTop: n, value: val1).get()
            try m.stack.set(indexFromTop: 0, value: val2).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
