import PrimitiveTypes

/// EVM BItwise instructions
enum BItwiseInstructions {
    static func lt(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue: UInt64 = (op1 < op2) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func gt(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue: UInt64 = (op1 > op2) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func slt(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let iOp1 = I256.fromU256(op1)
            let iOp2 = I256.fromU256(op2)

            let newValue: UInt64 = (iOp1 < iOp2) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func sgt(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let iOp1 = I256.fromU256(op1)
            let iOp2 = I256.fromU256(op2)

            let newValue: UInt64 = (iOp1 > iOp2) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func eq(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue: UInt64 = (op1 == op2) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func isZero(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()

            let newValue: UInt64 = (op1.isZero) ? 1 : 0
            try m.stack.push(value: U256(from: newValue)).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func and(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue = op1 & op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func or(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue = op1 | op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func xor(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let newValue = op1 ^ op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func not(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()

            let newValue = ~op1
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func byte(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            var newValue = U256.ZERO
            if op1 < U256(from: 32) {
                // Force get UInt, because we know it is less than 32
                let o = Int(op1.getUInt!)
                for i in 0 ..< 8 {
                    let t = 255 - (7 - i + 8 * o)
                    let value = (op2 >> t) & U256(from: 1)
                    newValue = newValue + (value << i)
                }
            }
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func shl(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            var newValue = U256.ZERO
            if !op2.isZero, op1 < U256(from: 256) {
                // Force get UInt, because we know it is less than 256
                let shift = Int(op1.getUInt!)
                newValue = op2 << shift
            }
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func shr(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            var newValue = U256.ZERO
            if !op2.isZero, op1 < U256(from: 256) {
                // Force get UInt, because we know it is less than 256
                let shift = Int(op1.getUInt!)
                newValue = op2 >> shift
            }
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func sar(machine m: inout Machine) {
        do {
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()

            let iOp2 = I256.fromU256(op2)

            var newValue = U256.ZERO
            if op2.isZero || op1 >= U256(from: 255) {
                // if value is < 0, pushing -1
                // else `Zero` (by default)
                if iOp2.signExtend, !op2.isZero {
                    newValue = I256(from: [1, 0, 0, 0], signExtend: true).toU256
                }
            } else {
                // Force get UInt, because we know it is less than 256
                let shift = Int(op1.getUInt!)
                // Check is positive number
                if !iOp2.signExtend {
                    // Shift Right
                    newValue = op2 >> shift
                } else {
                    // Shift Arithmetic Right
                    newValue = (iOp2 >> shift).toU256
                }
            }
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
