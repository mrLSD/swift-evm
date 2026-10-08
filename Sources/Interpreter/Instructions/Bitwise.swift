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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; this unwrap cannot fail.
        let op1 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

        let newValue = op1 & op2
        m.stackPush(value: newValue)
    }

    /// Pushes `a | b` onto the stack.
    ///
    /// Requires 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func or(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

        let newValue = op1 ^ op2
        m.stackPush(value: newValue)
    }

    /// Pushes `~a` onto the stack.
    ///
    /// Requires 1 stack item; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func not(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; this unwrap cannot fail.
        let op1 = m.stackPop()!

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

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

        var newValue = U256.ZERO
        if op1 < U256(from: 32) {
            // `op1 < 32` was checked above, so the conversion cannot fail.
            let shift = (31 - op1.getInt!) * 8
            newValue = (op2 >> shift) & U256(from: 0xFF)
        }
        m.stackPush(value: newValue)
    }

    /// Pushes `x << shift` onto the stack; pushes `0` if `x == 0` or `shift >= 256`.
    ///
    /// Requires Constantinople or later and 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func shl(machine m: Machine) {
        guard m.hardFork.isConstantinople() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

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
    /// Requires Constantinople or later and 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func shr(machine m: Machine) {
        guard m.hardFork.isConstantinople() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

        var newValue = U256.ZERO
        if !op2.isZero, op1 < U256(from: 256) {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            newValue = op2 >> shift
        }
        m.stackPush(value: newValue)
    }

    /// Pushes the arithmetic right shift of a signed 256-bit value.
    /// Requires Constantinople or later and 2 stack items; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.VERYLOW`).
    static func sar(machine m: Machine) {
        guard m.hardFork.isConstantinople() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let op1 = m.stackPop()!
        let op2 = m.stackPop()!

        let value = I256.fromU256(op2)
        let newValue = if value.isZero || op1 >= U256(from: 256) {
            value.signExtend ? U256.MAX : U256.ZERO
        } else {
            // Force get Int, because we know it is less than 256
            (value >> op1.getInt!).toU256
        }
        m.stackPush(value: newValue)
    }

    /// Pushes the number of leading zero bits of the top item (EIP-7939); pushes `256` for zero.
    ///
    /// Requires Osaka or later and 1 stack item; fails with `StackUnderflow` or `OutOfGas` (`GasConstant.LOW`).
    static func clz(machine m: Machine) {
        guard m.hardFork.isOsaka() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // Stack size was verified above; this unwrap cannot fail.
        let op1 = m.stackPop()!

        m.stackPush(value: U256(from: UInt64(op1.leadingZeroBitCount)))
    }
}
