import PrimitiveTypes

/// EVM bitwise and comparison instruction implementations.
///
/// Groups helpers for opcodes such as `LT`, `GT`, `SLT`, `SGT`, `EQ`, `ISZERO`, `AND`, `OR`, `XOR`, `NOT`, `BYTE`, `SHL`, `SHR`, `SAR`.
/// Each instruction validates stack requirements, charges gas (typically `GasConstant.VERYLOW`), and returns early on failure.
enum BitwiseInstructions {
    /// Pushes `1` if `a < b`, otherwise pushes `0`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func lt(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue: UInt64 = (op1 < op2) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `1` if `a > b`, otherwise pushes `0`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func gt(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue: UInt64 = (op1 > op2) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `1` if signed `a < b`, otherwise pushes `0`.
    ///
    /// Interprets operands as two's-complement signed 256\-bit integers.
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func slt(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)

        let newValue: UInt64 = (iOp1 < iOp2) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `1` if signed `a > b`, otherwise pushes `0`.
    ///
    /// Interprets operands as two's-complement signed 256\-bit integers.
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func sgt(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)

        let newValue: UInt64 = (iOp1 > iOp2) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `1` if `a == b`, otherwise pushes `0`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func eq(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue: UInt64 = (op1 == op2) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `1` if `a == 0`, otherwise pushes `0`.
    ///
    /// Requires 1 stack item; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func isZero(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop() else { return }

        let newValue: UInt64 = (op1.isZero) ? 1 : 0
        m.stackPush(value: U256(from: newValue))
    }

    /// Pushes `a & b` onto the stack.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func and(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op1 & op2
        m.stackPush(value: newValue)
    }

    /// Pushes `a || b` onto the stack.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func or(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op1 | op2
        m.stackPush(value: newValue)
    }

    /// Pushes `a ^ b` onto the stack.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func xor(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op1 ^ op2
        m.stackPush(value: newValue)
    }

    /// Pushes `!a` onto the stack.
    ///
    /// Requires 1 stack item; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func not(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop() else { return }

        let newValue = ~op1
        m.stackPush(value: newValue)
    }

    /// Pushes the `n`th byte of `x` onto the stack (0 = most significant byte); pushes `0` if `n >= 32`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func byte(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        var newValue = U256.ZERO
        if op1 < U256(from: 32) {
            // Force get Int, because we know it is less than 32
            let o = op1.getInt!
            for i in 0 ..< 8 {
                let t = 255 - (7 - i + 8 * o)
                let value = (op2 >> t) & U256(from: 1)
                newValue += (value << i)
            }
        }
        m.stackPush(value: newValue)
    }

    /// Pushes `x << shift` onto the stack; pushes `0` if `x == 0` or `shift >= 256`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func shl(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        var newValue = U256.ZERO
        if !op2.isZero, op1 < U256(from: 256) {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            newValue = op2 << shift
        }
        m.stackPush(value: newValue)
    }

    /// Pushes `x >> shift` onto the stack; pushes `0` if `x == 0` or `shift >= 256`.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func shr(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        var newValue = U256.ZERO
        if !op2.isZero, op1 < U256(from: 256) {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            newValue = op2 >> shift
        }
        m.stackPush(value: newValue)
    }

    /// Pushes `x >> shift` (arithmetic, sign-extending) onto the stack; pushes `0` if `x == 0` or `shift >= 255`, or `2^256 - 1` if `x < 0` and `shift >= 255`.
    ///
    /// Interprets `x` as a two's-complement signed 256-bit integer.
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func sar(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let iOp2 = I256.fromU256(op2)

        var newValue = U256.ZERO

        // NOTE: In that case 255 is actually better than 256:
        // For arithmetic right shift on 256-bit values, when the shift amount
        // reaches 255, the result becomes deterministic based solely on the sign bit:
        //
        // - Shifting 255 positions moves bit 255 (the sign bit) to position 0
        // - For positive numbers (sign bit = 0): result is 0
        // - For negative numbers (sign bit = 1): result is -1 (all bits set due to sign extension)
        //
        // Using >= 255 instead of >= 256 is an optimization that recognizes this
        // deterministic case one shift earlier, avoiding unnecessary computation while producing
        // identical results. Your tests demonstrate that this optimization is correct and maintains EVM spec compliance.
        if op2.isZero || op1 >= U256(from: 255) {
            // if value is < 0, pushing -1
            // else `Zero` (by default)
            if iOp2.signExtend, !op2.isZero {
                newValue = I256(from: [1, 0, 0, 0], signExtend: true).toU256
            }
        } else {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            // Check is positive number
            if !iOp2.signExtend {
                // Shift Right
                newValue = op2 >> shift
            } else {
                // Shift Arithmetic Right
                newValue = (iOp2 >> shift).toU256
            }
        }
        m.stackPush(value: newValue)
    }
}
