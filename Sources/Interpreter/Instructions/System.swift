import PrimitiveTypes

/// EVM System instructions
enum SystemInstructions {
    static func codeSize(machine m: inout Machine) {
        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.codeSize)
        m.stackPush(value: U256(from: newValue))
    }
}
