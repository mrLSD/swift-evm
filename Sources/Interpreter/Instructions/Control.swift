import PrimitiveTypes

/// EVM Control instructions
enum ControlInstructions {
    /// Pushes the current program counter (`pc`) onto the stack.
    ///
    /// Requires 0 stack items and pushes 1; fails with `OutOfGas` (`GasConstant.BASE`).
    static func pc(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.pc)
        m.stackPush(value: U256(from: newValue))
    }

    /// Halts execution successfully with the `STOP` exit reason.
    ///
    /// Requires 0 stack items; does not modify memory; consumes no additional gas beyond the opcode base cost handled by the interpreter loop.
    static func stop(machine m: Machine) {
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Success(Machine.ExitSuccess.Stop))
    }

    /// Marks a valid jump destination (`JUMPDEST`) and charges the fixed gas cost.
    ///
    /// Requires 0 stack items; consumes `GasConstant.JUMPDEST`; fails with `OutOfGas`.
    static func jumpDest(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.JUMPDEST) {
            return
        }
    }

    /// Pops a jump destination from the stack and transfers control to it if it is a valid `JUMPDEST`.
    ///
    /// Requires 1 stack item; consumes `GasConstant.MID`; fails with `OutOfGas` or exits with `.InvalidJump` for an invalid destination.
    static func jump(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.MID) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Get jump destination
        let target = m.stackPop()!

        if let dest = target.getInt, m.isValidJumpDestination(at: dest) {
            m.machineStatus = Machine.MachineStatus.Jump(dest)
        } else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.InvalidJump))
        }
    }

    /// Conditionally jumps to a destination popped from the stack when the condition value is non\-zero.
    ///
    /// Requires 2 stack items; consumes `GasConstant.HIGH`; continues without jumping if the condition is zero; fails with `OutOfGas` or exits with `.InvalidJump` for an invalid destination.
    static func jumpi(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.HIGH) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Get jump destination
        let target = m.stackPop()!
        let value = m.stackPop()!

        // A zero condition ignores the destination.
        if value.isZero {
            m.machineStatus = Machine.MachineStatus.Continue
            return
        }

        if let dest = target.getInt, m.isValidJumpDestination(at: dest) {
            m.machineStatus = Machine.MachineStatus.Jump(dest)
        } else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.InvalidJump))
        }
    }

    /// Returns successfully, setting the return data range from memory (`offset`, `length`) popped from the stack.
    ///
    /// Requires 2 stack items; resizes memory and charges the corresponding memory gas cost; exits with `.Return`.
    static func ret(machine m: Machine) {
        returnFromMemory(machine: m, reason: .Success(.Return))
    }

    /// Reverts execution (`REVERT`, EIP-140), returning data from memory (`offset`, `length`) popped from the stack.
    ///
    /// Requires Byzantium or later; requires 2 stack items; resizes memory and charges the corresponding memory gas cost; exits with `.Revert` (state changes are reverted).
    static func revert(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isByzantium() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        returnFromMemory(machine: m, reason: .Revert)
    }

    /// Prepares the return-data range from stack operands and halts execution.
    ///
    /// Pops the offset followed by the length and charges for any required memory expansion.
    /// A zero length ignores the offset and produces `0..<0` without accessing memory.
    /// Stack underflow or a memory failure sets an error exit instead of the supplied reason.
    ///
    /// - Parameters:
    ///   - m: The executing machine whose stack, memory, gas, and return state are updated.
    ///   - reason: The exit reason applied after preparing the range: `.Success(.Return)` or `.Revert`.
    private static func returnFromMemory(machine m: Machine, reason: Machine.ExitReason) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let rawOffset = m.stackPop()!
        let rawLength = m.stackPop()!
        guard let length = m.getMemoryIntOrFail(rawLength) else {
            return
        }

        // Empty output ignores the offset, even if it cannot fit in Int.
        var offset = 0
        if length > 0 {
            guard let memoryOffset = m.getMemoryIntOrFail(rawOffset) else {
                return
            }
            guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: length) else {
                return
            }
            offset = memoryOffset
        }

        // Memory expansion validated the nonempty range's upper bound.
        m.returnRange = offset ..< (offset + length)
        m.machineStatus = Machine.MachineStatus.Exit(reason)
    }
}
