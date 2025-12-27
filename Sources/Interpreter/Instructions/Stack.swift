import PrimitiveTypes

/// EVM stack instruction implementations.
///
/// Provides helpers for stack mutation opcodes (e.g. `POP`, `PUSH*`, `DUP*`, `SWAP*`).
/// Each instruction validates stack requirements, charges gas, and returns early on failure.
enum StackInstructions {
    /// Pops the top item from the stack.
    ///
    /// Fails with `StackUnderflow` if the stack is empty, or `OutOfGas` if `GasConstant.BASE` cannot be paid.
    static func pop(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        _ = m.stackPop()
    }

    /// ## Description
    /// Pushes the constant value 0 onto the stack.
    ///
    /// ## EIP
    /// EIP-3855: PUSH0 instruction
    /// https://eips.ethereum.org/EIPS/eip-3855
    static func push0(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256.ZERO)
    }

    /// Pushes an immediate value (`n` bytes) from code onto the stack.
    ///
    /// Reads up to `n` bytes starting at `pc + 1`, left--pads to 32 bytes, pushes the resulting `U256`,
    /// and advances `pc` by `n + 1`. Fails with `StackOverflow` (needs 1 free slot) or `OutOfGas` (`GasConstant.VERYLOW`).
    static func push(machine m: Machine, n: Int) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        let end = min(m.pc + 1 + n, m.codeSize)
        let slice = m.code[(m.pc + 1) ..< end]
        var val = [UInt8](repeating: 0, count: 32)
        val.replaceSubrange(32 - n ..< 32 - n + slice.count, with: slice)

        let newValue = U256.fromBigEndian(from: val)
        m.machineStatus = Machine.MachineStatus.AddPC(n + 1)
        m.stackPush(value: newValue)
    }

    /// Swaps the top stack item with the item `n` positions below it.
    ///
    /// Fails silently if either index is out of bounds. Costs `GasConstant.VERYLOW`.
    static func swap(machine m: Machine, n: Int) {
        if !m.verifyStack(pop: n + 1) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let val1 = m.stackPeek(indexFromTop: 0), let val2 = m.stackPeek(indexFromTop: n) else { return }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // In that particular case it's impossible to fail `stack.set` operations.
        // As we verified indexes 0 and N for `stack.peek` before.
        _ = m.stack.set(indexFromTop: n, value: val1)
        _ = m.stack.set(indexFromTop: 0, value: val2)
    }

    /// Duplicates the stack item `n` positions from the top and pushes the copy.
    ///
    /// Requires at least `n` items and 1 free slot; fails with `StackUnderflow`\/`StackOverflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func dup(machine m: Machine, n: Int) {
        if !m.verifyStack(pop: n, push: n + 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let dupVal = m.stackPeek(indexFromTop: n - 1) else { return }

        m.stackPush(value: dupVal)
    }
}
