import PrimitiveTypes

enum ArithmeticInstructions {
    static func add(machine m: inout Machine) {
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

    static func sub(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.VERYLOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let (newValue, _) = op1.overflowSub(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func mul(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = op1.mul(op2)
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func div(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = op2.isZero ? op2 : op1 / op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func rem(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let newValue = op2.isZero ? op2 : op1 % op2
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func sdiv(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let iOp1 = I256.fromU256(op1)
            let iOp2 = I256.fromU256(op2)
            let newValue = iOp1 / iOp2
            try m.stack.push(value: newValue.toU256).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func smod(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let iOp1 = I256.fromU256(op1)
            let iOp2 = I256.fromU256(op2)
            let newValue = iOp2.isZero ? iOp2 : iOp1 % iOp2
            try m.stack.push(value: newValue.toU256).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func addMod(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let op3 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.MID) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1u512 = U512(from: op1)
            let op2u512 = U512(from: op2)
            let op3u512 = U512(from: op3)

            var newValueu512 = U512.ZERO
            if !op3u512.isZero {
                // We ignore possible overflow, as we takes only first 4 elements from array as results
                newValueu512 = (op1u512 + op2u512) % op3u512
            }

            // Set first 4 elements from `U512`
            let newValue = U256(from: Array(newValueu512.BYTES.prefix(4)))
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func mulMod(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            let op3 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.MID) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let op1u512 = U512(from: op1)
            let op2u512 = U512(from: op2)
            let op3u512 = U512(from: op3)

            var newValueu512 = U512.ZERO
            if !op3u512.isZero {
                // We ignore possible overflow, as we takes only first 4 elements from array as results
                newValueu512 = (op1u512 * op2u512) % op3u512
            }

            // Set first 4 elements from `U512`
            let newValue = U256(from: Array(newValueu512.BYTES.prefix(4)))
            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    static func exp(machine m: inout Machine) {
        do {
            var op1 = try m.stack.pop().get()
            var op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.expCost(power: op2)) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            let one = U256(from: 1)
            var r = one

            while !op2.isZero {
                if !(op2 & one).isZero {
                    r = r * op1
                }
                op2 = op2 >> 1
                op1 = op1 * op1
            }
            let newValue = r

            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }

    /// In the yellow paper `SIGNEXTEND` is defined to take two inputs, we will call them
    /// `x` and `y`, and produce one output. The first `t` bits of the output (numbering from the
    /// left, starting from 0) are equal to the `t`-th bit of `y`, where `t` is equal to
    /// `256 - 8(x + 1)`. The remaining bits of the output are equal to the corresponding bits of `y`.
    /// Note: if `x >= 32` then the output is equal to `y` since `t <= 0`. To efficiently implement
    /// this algorithm in the case `x < 32` we do the following. Let `b` be equal to the `t`-th bit
    /// of `y` and let `s = 255 - t = 8x + 7` (this is effectively the same index as `t`, but
    /// numbering the bits from the right instead of the left). We can create a bit mask which is all
    /// zeros up to and including the `t`-th bit, and all ones afterwards by computing the quantity
    /// `2^s - 1`. We can use this mask to compute the output depending on the value of `b`.
    /// If `b == 1` then the yellow paper says the output should be all ones up to
    /// and including the `t`-th bit, followed by the remaining bits of `y`; this is equal to
    /// `y | !mask` where `|` is the bitwise `OR` and `!` is bitwise negation. Similarly, if
    /// `b == 0` then the yellow paper says the output should start with all zeros, then end with
    /// bits from `b`; this is equal to `y & mask` where `&` is bitwise `AND`.
    static func signextend(machine m: inout Machine) {
        do {
            let op1 = try m.stack.pop().get()
            let op2 = try m.stack.pop().get()
            if !m.gas.recordCost(cost: GasConstant.LOW) {
                m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.OutOfGas))
                return
            }

            var newValue = op2
            if op1 < U256(from: 32) {
                let bitIndex = Int(8 * op1.BYTES[0] + 7)
                let bit = op2.BYTES[bitIndex / 64] & (1 << (bitIndex % 64)) != 0
                let mask = (U256(from: 1) << bitIndex) - U256(from: 1)
                newValue = bit ? op2 | ~mask : op2 & mask
            }

            try m.stack.push(value: newValue).get()
        } catch {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(error))
        }
    }
}
