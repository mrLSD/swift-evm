import PrimitiveTypes

/// ## EVM Arithmetic instructions
///
/// EVM arithmetic opcode implementations.
///
/// `ArithmeticInstructions` groups pure, stateless handlers for arithmetic\-related EVM opcodes.
/// Each handler operates on a `Machine` instance by popping its operands from the stack,
/// charging the required gas via `gasRecordCost`, and pushing the resulting value back onto
/// the stack. On failure (e.g., insufficient stack items or gas), the handler returns early
/// without producing an output value.
///
/// This type is used as a namespacing container and is not intended to be instantiated.
enum ArithmeticInstructions {
    /// Executes the EVM `ADD` opcode (`0x01`).
    /// Pops two `U256` values, charges `VERYLOW` gas, and pushes the sum.
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func add(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let (newValue, _) = op1.overflowAdd(op2)
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `SUB` opcode (`0x03`).
    /// Pops two `U256` values, charges `VERYLOW` gas, and pushes the subtraction result.890da606ca60d93bffa02d536d8b93dbae5fd625
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func sub(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let (newValue, _) = op1.overflowSub(op2)
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `MUL` opcode (`0x02`).
    /// Pops two `U256` values, charges `LOW` gas, and pushes the product.
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func mul(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op1.mul(op2)
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `DIV` opcode (`0x04`).
    /// Pops two `U256` values, charges `LOW` gas, and pushes the quotient (or `0` if divisor is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func div(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op2.isZero ? op2 : op1 / op2
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `MOD` opcode (`0x06`).
    /// Pops two `U256` values, charges `LOW` gas, and pushes the remainder (or `0` if divisor is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func rem(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let newValue = op2.isZero ? op2 : op1 % op2
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `SDIV` opcode (`0x05`).
    /// Pops two `U256` values, charges `LOW` gas, and pushes the signed quotient (or `0` if divisor is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func sdiv(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)
        let newValue = iOp1 / iOp2
        m.stackPush(value: newValue.toU256)
    }

    /// Executes the EVM `SMOD` opcode (`0x07`).
    /// Pops two `U256` values, charges `LOW` gas, and pushes the signed remainder (or `0` if divisor is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func smod(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)
        let newValue = iOp2.isZero ? iOp2 : iOp1 % iOp2
        m.stackPush(value: newValue.toU256)
    }

    /// Executes the EVM `ADDMOD` opcode (`0x08`).
    /// Pops three `U256` values, charges `MID` gas, and pushes `(a + b) % m` (or `0` if modulus is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func addMod(machine m: Machine) {
        if !m.verifyStack(pop: 3) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.MID) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop(), let op3 = m.stackPop() else { return }

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
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `MULMOD` opcode (`0x09`).
    /// Pops three `U256` values, charges `MID` gas, and pushes `(a * b) % m` (or `0` if modulus is zero).
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func mulMod(machine m: Machine) {
        if !m.verifyStack(pop: 3) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.MID) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop(), let op3 = m.stackPop() else { return }

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
        m.stackPush(value: newValue)
    }

    /// Executes the EVM `EXP` opcode (`0x0a`).
    /// Pops two `U256` values, charges dynamic gas via `GasCost.expCost` (based on the exponent), and pushes the result.
    /// Returns early if the stack underflows or gas charging fails, leaving the machine unchanged.
    static func exp(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard var op2 = m.stackPeek(indexFromTop: 2) else { return }

        if !m.gasRecordCost(cost: GasCost.expCost(hardFork: m.hardFork, power: op2)) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard var op1 = m.stackPop(), let _ = m.stackPop() else { return }

        let one = U256(from: 1)
        var r = one

        while !op2.isZero {
            if !(op2 & one).isZero {
                r *= op1
            }
            op2 = op2 >> 1
            op1 *= op1
        }
        let newValue = r

        m.stackPush(value: newValue)
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
    static func signextend(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.LOW) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let op1 = m.stackPop(), let op2 = m.stackPop() else { return }

        var newValue = op2
        if op1 < U256(from: 32) {
            let bitIndex = Int(8 * op1.BYTES[0] + 7)
            let bit = op2.BYTES[bitIndex / 64] & (1 << (bitIndex % 64)) != 0
            let mask = (U256(from: 1) << bitIndex) - U256(from: 1)
            newValue = bit ? op2 | ~mask : op2 & mask
        }

        m.stackPush(value: newValue)
    }
}
