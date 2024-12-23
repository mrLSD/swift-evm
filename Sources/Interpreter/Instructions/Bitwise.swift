import PrimitiveTypes

/// EVM BItwise instructions
enum BItwiseInstructions {
    static func lt(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue: UInt64 = (op1 < op2) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func gt(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue: UInt64 = (op1 > op2) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func slt(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)

        let newValue: UInt64 = (iOp1 < iOp2) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func sgt(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let iOp1 = I256.fromU256(op1)
        let iOp2 = I256.fromU256(op2)

        let newValue: UInt64 = (iOp1 > iOp2) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func eq(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue: UInt64 = (op1 == op2) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func isZero(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }

        let newValue: UInt64 = (op1.isZero) ? 1 : 0
        _ = m.stack.push(value: U256(from: newValue))
    }

    static func and(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue = op1 & op2
        _ = m.stack.push(value: newValue)
    }

    static func or(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue = op1 | op2
        _ = m.stack.push(value: newValue)
    }

    static func xor(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let newValue = op1 ^ op2
        _ = m.stack.push(value: newValue)
    }

    static func not(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }

        let newValue = ~op1
        _ = m.stack.push(value: newValue)
    }

    static func byte(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        var newValue = U256.ZERO
        if op1 < U256(from: 32) {
            // Force get Int, because we know it is less than 32
            let o = op1.getInt!
            for i in 0 ..< 8 {
                let t = 255 - (7 - i + 8 * o)
                let value = (op2 >> t) & U256(from: 1)
                newValue = newValue + (value << i)
            }
        }
        _ = m.stack.push(value: newValue)
    }

    static func shl(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        var newValue = U256.ZERO
        if !op2.isZero, op1 < U256(from: 256) {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            newValue = op2 << shift
        }
        _ = m.stack.push(value: newValue)
    }

    static func shr(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        var newValue = U256.ZERO
        if !op2.isZero, op1 < U256(from: 256) {
            // Force get Int, because we know it is less than 256
            let shift = op1.getInt!
            newValue = op2 >> shift
        }
        _ = m.stack.push(value: newValue)
    }

    static func sar(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }
        guard let op1 = m.stackPop() else {
            return
        }
        guard let op2 = m.stackPop() else {
            return
        }

        let iOp2 = I256.fromU256(op2)

        var newValue = U256.ZERO
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
        _ = m.stack.push(value: newValue)
    }
}
