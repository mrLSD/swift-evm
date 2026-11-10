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

        // Stack size was verified above; this unwrap cannot fail.
        let rawIndex = m.stackPeek(indexFromTop: 0)!
        guard let index = m.getMemoryIntOrFail(rawIndex) else {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }

        // Stack depth was verified above; the range was expanded above.
        m.stack.consume(count: 1)
        m.stackPush(value: m.memory.getWord(offset: index))
    }

    /// Stores a 32-byte word to memory at the byte offset popped from the stack.
    ///
    /// Requires 2 stack items; consumes `GasConstant.VERYLOW`; resizes memory to cover [`offset`, `offset + 32`) and charges the corresponding memory expansion gas.
    static func mstore(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let rawIndex = m.stackPeek(indexFromTop: 0)!
        guard let index = m.getMemoryIntOrFail(rawIndex) else {
            return
        }
        let value = m.stackPeek(indexFromTop: 1)!

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 32) else {
            return
        }

        // Stack depth was verified above; the range was expanded above, so the write cannot fail.
        m.stack.consume(count: 2)
        m.memory.writeWord(offset: index, value)
    }

    /// Stores the low byte of the value popped from the stack to memory at the byte offset popped from the stack.
    ///
    /// Requires 2 stack items; consumes `GasConstant.VERYLOW`; resizes memory to cover [`offset`, `offset + 1`) and charges the corresponding memory expansion gas.
    static func mstore8(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let rawIndex = m.stackPeek(indexFromTop: 0)!
        guard let index = m.getMemoryIntOrFail(rawIndex) else {
            return
        }
        let value = m.stackPeek(indexFromTop: 1)!

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: index, size: 1) else {
            return
        }

        // Stack depth was verified above; masking leaves a single byte, so the conversion cannot fail.
        m.stack.consume(count: 2)
        m.memory.writeByte(offset: index, UInt8((value & U256(from: 0xFF)).getInt!))
    }

    /// Copies a memory range, including overlapping ranges, from Cancun onward.
    ///
    /// Requires destination, source and size; charges copy gas and expands both ranges before copying.
    static func mcopy(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isCancun() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 3) {
            return
        }

        // Stack depth was verified above; these unwraps cannot fail.
        let rawDestination = m.stackPeek(indexFromTop: 0)!
        let rawSource = m.stackPeek(indexFromTop: 1)!
        let rawSize = m.stackPeek(indexFromTop: 2)!
        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // An empty copy ignores both offsets and does not expand memory.
        var destination = 0
        var source = 0
        if size > 0 {
            guard let dst = m.getMemoryIntOrFail(rawDestination) else {
                return
            }
            destination = dst
            guard let src = m.getMemoryIntOrFail(rawSource) else {
                return
            }
            source = src
        }

        if !m.gasRecordCost(cost: GasCost.veryLowCopy(size: size)) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: max(destination, source), size: size) else {
            return
        }

        m.stack.consume(count: 3)
        // Both ranges are allocated within the memory limit, so copy cannot fail.
        _ = m.memory.copy(srcOffset: source, dstOffset: destination, size: size)
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
