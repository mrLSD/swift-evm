import PrimitiveTypes

/// EVM Memory instructions
enum MemoryInstructions {
    /// Loads a 32-byte word from memory at the byte offset popped from the stack and pushes it as a `U256`.
    ///
    /// Requires 1 stack item; consumes `GasConstant.VERYLOW`; resizes memory to cover [`offset`, `offset + 32`) and charges the corresponding memory expansion gas.
    static func mload(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let rawIndex = m.stackPop() else { return }

        guard let index = m.getIntOrFail(rawIndex) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }
        let val = m.memory.get(offset: index, size: 32)
        m.stackPush(value: U256.fromBigEndian(from: val))
    }

    /// Stores a 32-byte word to memory at the byte offset popped from the stack.
    ///
    /// Requires 2 stack items; consumes GasConstant.VERYLOW; resizes memory to cover [offset, offset + 32) and charges the corresponding memory expansion gas; exits with the underlying memory error on failure.
    static func mstore(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let rawIndex = m.stackPop(), let value = m.stackPop() else { return }

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

    /// Stores the low byte of the value popped from the stack to memory at the byte offset popped from the stack.
    ///
    /// Requires 2 stack items; consumes `GasConstant.VERYLOW`; resizes memory to cover [`offset`, `offset + 1`) and charges the corresponding memory expansion gas; exits with the underlying memory error on failure.
    static func mstore8(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let rawIndex = m.stackPop(), let value = m.stackPop() else { return }

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

    /// Pushes the current effective memory size (in bytes) onto the stack.
    ///
    /// Requires 0 stack items and pushes 1 item; consumes `GasConstant.BASE`.
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
