import PrimitiveTypes

enum ArithmeticInstructions {
    static func add(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let (newValue, _) = op1.overflowAdd(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
