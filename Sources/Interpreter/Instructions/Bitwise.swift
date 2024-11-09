import Foundation
import PrimitiveTypes

/// EVM BItwise instructions
enum BItwiseInstructions {
    static func and(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let (newValue, _) = op1.overflowAdd(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
