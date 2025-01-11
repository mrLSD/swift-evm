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
}
