import PrimitiveTypes

enum ArithmeticInstructions {
    static func add(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let (newValue, _) = op1.overflowAdd(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func sub(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let (newValue, _) = op1.overflowSub(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func mul(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let newValue = op1.mul(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func div(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let newValue = op2.isZero ? op2 : op1 / op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func rem(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let newValue = op2.isZero ? op2 : op1 % op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
