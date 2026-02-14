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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        // Get jump destination
        guard let target = m.stackPop() else { return }

        // Convert jump destination
        guard let dest = m.getIntOrFail(target) else {
            return
        }

        // Validate jump destination
        if m.isValidJumpDestination(at: dest) {
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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        // Get jump destination
        guard let target = m.stackPop(), let value = m.stackPop() else { return }

        // Jump destination can't be zero
        if value.isZero {
            m.machineStatus = Machine.MachineStatus.Continue
            return
        }

        // Convert jump destination
        guard let dest = m.getIntOrFail(target) else {
            return
        }

        // Validate jump destination
        if m.isValidJumpDestination(at: dest) {
            m.machineStatus = Machine.MachineStatus.Jump(dest)
        } else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.InvalidJump))
        }
    }

    /// Returns successfully, setting the return data range from memory (`offset`, `length`) popped from the stack.
    ///
    /// Requires 2 stack items; resizes memory and charges the corresponding memory gas cost; exits with `.Return`.
    static func ret(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.// Pop values
        guard let rawOffset = m.stackPop(), let rawLength = m.stackPop() else { return }

        // Convert values
        guard let offset = m.getIntOrFail(rawOffset) else {
            return
        }
        guard let length = m.getIntOrFail(rawLength) else {
            return
        }

        // Resize memory
        if length > 0 {
            guard m.resizeMemoryAndRecordGas(offset: offset, size: length) else {
                return
            }
        }
        // Set return range
        m.returnRange = offset ..< (offset + length)
        // Set machine status
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Success(.Return))
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

        if !m.verifyStack(pop: 2) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let rawOffset = m.stackPop(), let rawLength = m.stackPop() else { return }

        // Convert values
        guard let offset = m.getIntOrFail(rawOffset) else {
            return
        }
        guard let length = m.getIntOrFail(rawLength) else {
            return
        }

        // Resize memory
        if length > 0 {
            guard m.resizeMemoryAndRecordGas(offset: offset, size: length) else {
                return
            }
        }
        // Set return range
        m.returnRange = offset ..< (offset + length)
        // Set machine status
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Revert)
    }
}
