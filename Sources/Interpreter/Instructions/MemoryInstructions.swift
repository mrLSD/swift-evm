import PrimitiveTypes

/// EVM Memory instructions
enum MemoryInstructions {
    static func mload(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let rawIndex = m.stackPop() else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let index = rawIndex.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }
        let val = m.memory.get(offset: index, size: 32)
        m.stackPush(value: U256.fromBigEndian(from: val))
    }
}
