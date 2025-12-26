import PrimitiveTypes

/// EVM Memory instructions
enum MemoryInstructions {
    static func mload(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard let rawIndex = m.stackPop() else {
            return
        }

        guard let index = m.getIntOrFail(rawIndex) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }
        let val = m.memory.get(offset: index, size: 32)
        m.stackPush(value: U256.fromBigEndian(from: val))
    }

    static func mstore(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Pop data
        guard let rawIndex = m.stackPop() else {
            return
        }
        guard let value = m.stackPop() else {
            return
        }

        guard let index = m.getIntOrFail(rawIndex) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }

        if case .failure(let err) = m.memory.set(offset: index, value: value.toBigEndian, size: 32) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func mstore8(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Pop data
        guard let rawIndex = m.stackPop() else {
            return
        }
        guard let value = m.stackPop() else {
            return
        }

        guard let index = m.getIntOrFail(rawIndex) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 1) else {
            return
        }

        let byteValue = UInt8(value.BYTES[0] & 0xFF)
        if case .failure(let err) = m.memory.set(offset: index, value: [byteValue], size: 1) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    static func msize(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256(from: UInt64(m.memory.effectiveLength)))
    }
}
