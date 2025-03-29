import PrimitiveTypes

/// EVM System instructions
enum SystemInstructions {
    static func codeSize(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.codeSize)
        m.stackPush(value: U256(from: newValue))
    }

    /// Performs a code copy operation by reading parameters from the machine's stack,
    /// calculating the associated gas costs, and executing the memory copy.
    static func codeCopy(machine m: inout Machine) {
        // Pop the required values from the stack: memory offset, code offset, and size.
        guard let rawMemoryOffset = m.stackPop(),
              let rawCodeOffset = m.stackPop(),
              let rawSize = m.stackPop()
        else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = rawSize.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }

        // Calculate the gas cost for the very low copy operation.
        let cost = GasCost.veryLowCopy(size: size)

        // Record the gas cost for the copy operation.
        if !m.gasRecordCost(cost: cost) {
            return
        }

        // If the size is zero, no copying is required.
        if size == 0 {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = rawMemoryOffset.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }
        guard let codeOffset = rawCodeOffset.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Perform the code copy. If the copy fails, update the machine status with the error.
        if case .failure(let err) = m.memory.copyData(memoryOffset: memoryOffset, dataOffset: codeOffset, size: size, data: m.code) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func callDataSize(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.data.count)
        m.stackPush(value: U256(from: newValue))
    }
}
