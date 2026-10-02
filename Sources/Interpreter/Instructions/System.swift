import CryptoSwift
import PrimitiveTypes

/// EVM System instructions
///
/// This enum provides static functions for EVM system-level opcodes such as CODECOPY, CALLDATACOPY, CALLVALUE, KECCAK256, etc.
enum SystemInstructions {
    /// Pushes the size of the current code onto the stack.
    static func codeSize(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.codeSize)
        m.stackPush(value: U256(from: newValue))
    }

    /// Performs a code copy operation by reading parameters from the machine's stack,
    /// calculating the associated gas costs, and executing the memory copy.
    static func codeCopy(machine m: Machine) {
        if !m.verifyStack(pop: 3) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Peek the required values from the stack: memory offset, code offset, and size.
        let rawMemoryOffset = m.stackPeek(indexFromTop: 0)!
        let rawCodeOffset = m.stackPeek(indexFromTop: 1)!
        let rawSize = m.stackPeek(indexFromTop: 2)!

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = m.getIntOrFail(rawSize) else {
            return
        }

        // Calculate the gas cost for the very low copy operation.
        let cost = GasCost.veryLowCopy(size: size)

        // Record the gas cost for the code copy operation.
        if !m.gasRecordCost(cost: cost) {
            return
        }

        // If the size is zero, no copying is required.
        if size == 0 {
            m.stack.consume(count: 3)
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        let codeOffset = rawCodeOffset.saturatingInt

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 3)

        // Perform the code copy. If the copy fails, update the machine status with the error.
        if case .failure(let err) = m.memory.copyData(memoryOffset: memoryOffset, dataOffset: codeOffset, size: size, data: m.code) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    /// Pushes the size of the call data onto the stack.
    static func callDataSize(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.data.count)
        m.stackPush(value: U256(from: newValue))
    }

    /// Copies call data into memory at the specified offset and size.
    static func callDataCopy(machine m: Machine) {
        if !m.verifyStack(pop: 3) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Peek the required values from the stack: memory offset, code offset, and size.
        let rawMemoryOffset = m.stackPeek(indexFromTop: 0)!
        let rawDataOffset = m.stackPeek(indexFromTop: 1)!
        let rawSize = m.stackPeek(indexFromTop: 2)!

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = m.getIntOrFail(rawSize) else {
            return
        }

        // Calculate the gas cost for the very low copy operation.
        let cost = GasCost.veryLowCopy(size: size)

        // Record the gas cost for the call data copy operation.
        if !m.gasRecordCost(cost: cost) {
            return
        }

        // If the size is zero, no copying is required.
        if size == 0 {
            m.stack.consume(count: 3)
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        let dataOffset = rawDataOffset.saturatingInt

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 3)

        // Perform the call-data copy. If the copy fails, update the machine status with the error.
        if case .failure(let err) = m.memory.copyData(memoryOffset: memoryOffset, dataOffset: dataOffset, size: size, data: m.data) {
            m.machineStatus = Machine.MachineStatus.Exit(err)
        }
    }

    /// Loads 32 bytes from call data at the specified index and pushes it onto the stack.
    static func callDataLoad(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.VERYLOW) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let index = m.stackPop()!

        let offset = index.saturatingInt
        let newValue: U256
        if offset < m.data.count {
            let count = min(32, m.data.count - offset)
            newValue = m.data.withUnsafeBytes {
                U256(bigEndian: UnsafeRawBufferPointer(rebasing: $0[offset ..< offset + count]))
            } << ((32 - count) * 8)
        } else {
            newValue = .ZERO
        }
        m.stackPush(value: newValue)
    }

    /// Pushes the call value onto the stack.
    static func callValue(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }
        m.stackPush(value: m.context.callValue)
    }

    /// Pushes the address of the currently executing account onto the stack.
    static func address(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        // Push the address of the current contract onto the stack
        m.stackPush(value: U256(from: H256(from: m.context.targetAddress)))
    }

    /// Pushes the caller address onto the stack.
    static func caller(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        // Push the caller address onto the stack
        m.stackPush(value: U256(from: H256(from: m.context.callerAddress)))
    }

    /// Pushes the remaining gas after paying for this instruction onto the stack.
    static func gas(machine m: Machine) {
        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        m.stackPush(value: U256(from: m.gas.remaining))
    }

    /// Computes the Keccak-256 hash of a memory region and pushes the result onto the stack.
    static func keccak256(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Peek the required values from the stack: memory offset and size.
        let rawMemoryOffset = m.stackPeek(indexFromTop: 0)!
        let rawSize = m.stackPeek(indexFromTop: 1)!

        // This situation possible only for 32-bit context (for example wasm32)
        guard let size = m.getIntOrFail(rawSize) else {
            return
        }

        // Calculate the gas cost for Keccak256 operation.
        let cost = GasCost.keccak256Cost(size: size)

        // Record the gas cost for the Keccak256 operation.
        if !m.gasRecordCost(cost: cost) {
            return
        }

        // Short-circuit for empty input: keccak256("") is a well-known constant.
        // Per Yellow Paper: with size == 0 no memory access happens, so memory offset
        // validation and memory expansion are both skipped.
        if size == 0 {
            // Stack depth was verified above.
            m.stack.consume(count: 2)
            m.stackPush(value: U256(from: H256.KECCAK_EMPTY))
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 2)

        let data = m.memory.get(offset: memoryOffset, size: size)

        let keccakHashBytes = data.sha3(.keccak256)
        let newValue = U256.fromBigEndian(from: keccakHashBytes)
        m.stackPush(value: newValue)
    }
}
