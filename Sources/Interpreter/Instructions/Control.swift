import PrimitiveTypes

/// EVM Control instructions
enum ControlInstructions {
    static func pc(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.pc)
        m.stackPush(value: U256(from: newValue))
    }

    static func stop(machine m: inout Machine) {
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Success(Machine.ExitSuccess.Stop))
    }

    static func jumpDest(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.JUMPDEST) {
            return
        }
    }

    static func jump(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.MID) {
            return
        }

        // Get jump destination
        guard let target = m.stackPop() else {
            return
        }
        guard let dest = target.getInt else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.IntOverflow))
            return
        }

        // Validate jump destination
        if m.isValidJumpDestination(at: dest) {
            m.machineStatus = Machine.MachineStatus.Jump(dest)
        } else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.InvalidJump))
        }
    }

    static func jumpi(machine m: inout Machine) {
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

        if value.isZero {
            m.machineStatus = Machine.MachineStatus.Continue
            return
        }

        guard let dest = target.getInt else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.IntOverflow))
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
    static func ret(machine m: inout Machine) {
        guard let rawOffset = m.stackPop(), let rawLength = m.stackPop() else {
            return
        }
        // Convert values
        guard let offset = m.getUintOrFail(rawOffset), let length = m.getUintOrFail(rawLength) else {
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
    static func revert(machine m: inout Machine) {
        guard m.hardFork.isByzantium() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        guard let rawOffset = m.stackPop(), let rawLength = m.stackPop() else {
            return
        }
        // Convert values
        guard let offset = m.getUintOrFail(rawOffset), let length = m.getUintOrFail(rawLength) else {
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
