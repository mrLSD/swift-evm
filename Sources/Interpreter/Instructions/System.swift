import PrimitiveTypes

/// EVM System instructions
enum SystemInstructions {
    static func codeSize(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.codeSize)
        m.stackPush(value: U256(from: newValue))
    }

    /// Performs a code copy operation by reading parameters from the machine's stack,
    /// calculating the associated gas costs, and executing the memory copy.
    static func codeCopy(machine m: Machine) {
        // Pop the required values from the stack: memory offset, code offset, and size.
        guard let rawMemoryOffset = m.stackPop() else {
            return
        }
        guard let rawCodeOffset = m.stackPop() else {
            return
        }
        guard let rawSize = m.stackPop() else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = m.getIntOrFail(rawSize) else {
            return
        }

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
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        guard let codeOffset = m.getIntOrFail(rawCodeOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Perform the code copy. If the copy fails, update the machine status with the error.
        if case .failure(let err) = m.memory.copyData(memoryOffset: memoryOffset, dataOffset: codeOffset, size: size, data: m.code) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func callDataSize(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.data.count)
        m.stackPush(value: U256(from: newValue))
    }

    static func callDataCopy(machine m: Machine) {
        // Pop the required values from the stack: memory offset, code offset, and size.
        guard let rawMemoryOffset = m.stackPop() else {
            return
        }
        guard let rawDataOffset = m.stackPop() else {
            return
        }
        guard let rawSize = m.stackPop() else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = m.getIntOrFail(rawSize) else {
            return
        }

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
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        guard let dataOffset = m.getIntOrFail(rawDataOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Perform the call-data copy. If the copy fails, update the machine status with the error.
        if case .failure(let err) = m.memory.copyData(memoryOffset: memoryOffset, dataOffset: dataOffset, size: size, data: m.data) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func callDataLoad(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let index = m.stackPop() else {
            return
        }

        var load = [UInt8](repeating: 0, count: 32)
        let dataCount = m.data.count
        if let intIndex = index.getInt, intIndex < dataCount {
            let countToCopy = min(32, dataCount - intIndex)

            let sourceRange = intIndex ..< (intIndex + countToCopy)
            let destinationRange = 0 ..< countToCopy
            load.replaceSubrange(destinationRange, with: m.data[sourceRange])
        }
        let newValue = U256.fromBigEndian(from: load)
        m.stackPush(value: newValue)
    }

    static func callValue(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }
        m.stackPush(value: m.context.value)
    }
}
