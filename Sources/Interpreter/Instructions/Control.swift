import PrimitiveTypes

/// EVM Control instructions
enum ControlInstructions {
    static func pc(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.BASE) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = UInt64(m.pc)
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func stop(machine m: inout Machine) {
        m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Success(Machine.ExitSuccess.Stop))
    }

    static func jumpDest(machine m: inout Machine) {
        if !m.gas.recordCost(cost: GasConstant.JUMPDEST) {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
            return
        }
    }

    static func jump(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.MID) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            // Get jump destination
            let target = try m.stack.pop().get()
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
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func jumpi(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.HIGH) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            // Get jump destination
            let target = try m.stack.pop().get()
            let value = try m.stack.pop().get()

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
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
