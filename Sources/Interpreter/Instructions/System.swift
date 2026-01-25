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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        // Pop the required values from the stack: memory offset, code offset, and size.
        guard let rawMemoryOffset = m.stackPop(), let rawCodeOffset = m.stackPop(), let rawSize = m.stackPop() else { return }

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
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        guard let codeOffset = m.getIntOrFail(rawCodeOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        // Peek the required values from the stack: memory offset, code offset, and size.
        guard let rawMemoryOffset = m.stackPeek(indexFromTop: 0), let rawDataOffset = m.stackPeek(indexFromTop: 1), let rawSize = m.stackPeek(indexFromTop: 2) else { return }

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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let _ = m.stackPop(), let _ = m.stackPop(), let _ = m.stackPop() else { return }

        // If the size is zero, no copying is required.
        if size == 0 {
            return
        }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }
        guard let dataOffset = m.getIntOrFail(rawDataOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let index = m.stackPop() else { return }

        var load = [UInt8](repeating: 0, count: 32)
        let dataCount = m.data.count
        if let intIndex = index.getInt, intIndex < dataCount {
            let countToCopy = min(32, dataCount - intIndex)

            let sourceRange = intIndex ..< (intIndex + countToCopy)
            let destinationRange = 0 ..< countToCopy
            load.replaceSubrange(destinationRange, with: m.data[sourceRange])
        }
        let newValue = U256.fromBigEndian(from: load)
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
        let newValue = H256(from: m.context.targetAddress).BYTES
        m.stackPush(value: U256.fromBigEndian(from: newValue))
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
        let newValue = H256(from: m.context.callerAddress).BYTES
        m.stackPush(value: U256.fromBigEndian(from: newValue))
    }

    /// Computes the Keccak-256 hash of a memory region and pushes the result onto the stack.
    static func keccak256(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        // Peek the required values from the stack: memory offset and size.
        guard let rawMemoryOffset = m.stackPeek(indexFromTop: 0), let rawSize = m.stackPeek(indexFromTop: 1) else { return }

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

        // After stack verification this guard will always succeed. But we keep it for safety and clarity.
        guard let _ = m.stackPop(), let _ = m.stackPop() else { return }

        // This situation possible only for 32-bit context (for example wasm32)
        guard let memoryOffset = m.getIntOrFail(rawMemoryOffset) else {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        let data = m.memory.get(offset: memoryOffset, size: size)

        let keccakHashBytes = data.sha3(.keccak256)
        let newValue = U256.fromBigEndian(from: keccakHashBytes)
        m.stackPush(value: newValue)
    }
}
