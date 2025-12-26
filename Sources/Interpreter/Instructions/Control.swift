import PrimitiveTypes

/// EVM Control instructions
enum ControlInstructions {
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

    static func stop(machine m: Machine) {
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Success(Machine.ExitSuccess.Stop))
    }

    static func jumpDest(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.JUMPDEST) {
            return
        }
    }

    static func jump(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.MID) {
            return
        }

        // Get jump destination
        guard let target = m.stackPop() else {
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

    static func jumpi(machine m: Machine) {
        if !m.gasRecordCost(cost: GasConstant.HIGH) {
            return
        }

        // Get jump destination
        guard let target = m.stackPop() else {
            return
        }
        guard let value = m.stackPop() else {
            return
        }

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

    /// `Return` instruction
    static func ret(machine m: Machine) {
        // Pop values
        guard let rawOffset = m.stackPop() else {
            return
        }
        guard let rawLength = m.stackPop() else {
            return
        }

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

    /// `Revert` instruction
    /// `EIP-140`: REVERT instruction
    static func revert(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isByzantium() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        

        // Pop values
        guard let rawOffset = m.stackPop() else {
            return
        }
        guard let rawLength = m.stackPop() else {
            return
        }

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
