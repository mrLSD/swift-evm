import PrimitiveTypes

/// EVM System instructions
enum SystemInstructions {
    static func codeSize(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = UInt64(m.codeSize)
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func pc(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = UInt64(m.pc)
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func pop(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let _ = try m.stack.pop().get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
