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

    static func mstore(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let rawIndex = m.stackPop(),
              let value = m.stackPop()
        else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let index = rawIndex.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }

        if case .failure(let err) = m.memory.set(offset: index, value: value.toBigEndian, size: 32) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func mstore8(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let rawIndex = m.stackPop(),
              let value = m.stackPop()
        else {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let index = rawIndex.getUInt else { m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas)); return }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 1) else {
            return
        }

        let byteValue = UInt8(value.BYTES[0] & 0xFF)
        if case .failure(let err) = m.memory.set(offset: index, value: [byteValue], size: 1) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func msize(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256(from: UInt64(m.memory.effectiveLength)))
    }
}
