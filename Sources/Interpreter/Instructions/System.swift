import EVMCrypto
import PrimitiveTypes

/// EVM System instructions
///
/// This enum provides static functions for EVM system-level opcodes such as CODECOPY, CALLDATACOPY, CALLVALUE, KECCAK256, etc.
enum SystemInstructions {
    /// Loads a word from the executing account's persistent storage.
    static func sload(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        // Stack depth was verified above; this unwrap cannot fail.
        let index = H256(from: m.stackPeek(indexFromTop: 0)!)
        let address = m.context.targetAddress
        var isCold = false
        if m.hardFork.isBerlin() {
            isCold = m.state.isCold(address: address, index: index)
            m.state.warm(address: address, index: index, isCold: isCold)
        }
        if !m.gasRecordCost(cost: GasCost.sloadCost(hardFork: m.hardFork, isCold: isCold)) {
            return
        }

        let value = m.handler.storage(address: address, index: index)
        m.stack.consume(count: 1)
        m.stackPush(value: U256(from: value))
    }

    /// Stores a word in the executing account's persistent storage.
    static func sstore(machine m: Machine) {
        if !m.verifyStack(pop: 2) {
            return
        }
        if m.handler.isStatic() {
            m.machineStatus = .Exit(.Error(.WriteInStaticContext))
            return
        }
        if m.hardFork.isIstanbul() && m.gas.remaining <= GasConstant.CALL_STIPEND {
            m.machineStatus = .Exit(.Error(.OutOfGas))
            return
        }

        // Stack depth was verified above; these unwraps cannot fail.
        let index = H256(from: m.stackPeek(indexFromTop: 0)!)
        let value = H256(from: m.stackPeek(indexFromTop: 1)!)
        let address = m.context.targetAddress
        var isCold = false
        if m.hardFork.isBerlin() {
            isCold = m.state.isCold(address: address, index: index)
            m.state.warm(address: address, index: index, isCold: isCold)
        }
        let original = m.hardFork.isIstanbul() ? m.handler.originalStorage(address: address, index: index) : .ZERO
        let current = m.handler.storage(address: address, index: index)
        if !m.gasRecordCost(cost: GasCost.sstoreCost(hardFork: m.hardFork, original: original, current: current, new: value, isCold: isCold)) {
            return
        }

        switch m.handler.setStorage(address: address, index: index, value: value) {
        case .success:
            m.gas.recordRefund(refund: GasCost.sstoreRefund(hardFork: m.hardFork, original: original, current: current, new: value))
            m.stack.consume(count: 2)
        case .failure(let error):
            m.machineStatus = .Exit(.Error(error))
        }
    }

    /// EIP-1153: loads a word from the executing account's transient storage.
    static func tload(machine m: Machine) {
        guard m.hardFork.isCancun() else {
            m.machineStatus = .Exit(.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.WARM_STORAGE_READ_COST) {
            return
        }

        // Stack depth was verified above; this unwrap cannot fail.
        let index = H256(from: m.stackPeek(indexFromTop: 0)!)
        switch m.handler.tload(address: m.context.targetAddress, index: index) {
        case .success(let value):
            m.stack.consume(count: 1)
            m.stackPush(value: value)
        case .failure(let error):
            m.machineStatus = .Exit(.Error(error))
        }
    }

    /// EIP-1153: stores a word in the executing account's transient storage.
    static func tstore(machine m: Machine) {
        guard m.hardFork.isCancun() else {
            m.machineStatus = .Exit(.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 2) {
            return
        }

        if m.handler.isStatic() {
            m.machineStatus = .Exit(.Error(.WriteInStaticContext))
            return
        }

        if !m.gasRecordCost(cost: GasConstant.WARM_STORAGE_READ_COST) {
            return
        }

        // Stack depth was verified above; these unwraps cannot fail.
        let index = H256(from: m.stackPeek(indexFromTop: 0)!)
        let value = m.stackPeek(indexFromTop: 1)!
        switch m.handler.tstore(address: m.context.targetAddress, index: index, value: value) {
        case .success:
            m.stack.consume(count: 2)
        case .failure(let error):
            m.machineStatus = .Exit(.Error(error))
        }
    }

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

    /// Pushes the size of an account's own code onto the stack.
    static func extCodeSize(machine m: Machine) {
        if !m.verifyStack(pop: 1) {
            return
        }

        // Stack size was verified above; this unwrap cannot fail.
        let rawAddress = m.stackPeek(indexFromTop: 0)!
        let address = H256(from: rawAddress).toH160()

        var isCold = false
        if m.hardFork.isBerlin() {
            isCold = m.state.isCold(address: address)
            m.state.warm(address: address, isCold: isCold)
        }
        if !m.gasRecordCost(cost: GasCost.extCodeAccessCost(hardFork: m.hardFork, isCold: isCold)) {
            return
        }

        m.stack.consume(count: 1)
        m.stackPush(value: U256(from: UInt64(m.handler.code(address: address).count)))
    }

    /// Pushes the account's own code hash, or zero for an EIP-161 empty account.
    static func extCodeHash(machine m: Machine) {
        guard m.hardFork.isConstantinople() else {
            m.machineStatus = .Exit(.Error(.HardForkNotActive))
            return
        }
        if !m.verifyStack(pop: 1) {
            return
        }

        // Stack size was verified above; this unwrap cannot fail.
        let rawAddress = m.stackPeek(indexFromTop: 0)!
        let address = H256(from: rawAddress).toH160()

        var isCold = false
        if m.hardFork.isBerlin() {
            isCold = m.state.isCold(address: address)
            m.state.warm(address: address, isCold: isCold)
        }
        if !m.gasRecordCost(cost: GasCost.extCodeHashCost(hardFork: m.hardFork, isCold: isCold)) {
            return
        }

        m.stack.consume(count: 1)

        let codeHash = m.handler.codeHash(address: address)
        m.stackPush(value: U256(from: codeHash))
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

        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // An empty range ignores the offset and does not expand memory.
        var memoryOffset = 0
        if size > 0 {
            guard let offset = m.getMemoryIntOrFail(rawMemoryOffset) else {
                return
            }
            memoryOffset = offset
        }

        let cost = GasCost.veryLowCopy(size: size)
        if !m.gasRecordCost(cost: cost) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 3)
        if size == 0 {
            return
        }

        let codeOffset = rawCodeOffset.saturatingInt

        // The range was expanded above, so the copy cannot fail; bytes past the code are zero-filled.
        m.memory.writeData(offset: memoryOffset, size: size, from: m.code, dataOffset: codeOffset)
    }

    /// Copies an account's own code into memory, zero-filling bytes beyond its end.
    static func extCodeCopy(machine m: Machine) {
        if !m.verifyStack(pop: 4) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let rawAddress = m.stackPeek(indexFromTop: 0)!
        let rawMemoryOffset = m.stackPeek(indexFromTop: 1)!
        let rawCodeOffset = m.stackPeek(indexFromTop: 2)!
        let rawSize = m.stackPeek(indexFromTop: 3)!

        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // An empty range ignores the offset and does not expand memory.
        var memoryOffset = 0
        if size > 0 {
            guard let offset = m.getMemoryIntOrFail(rawMemoryOffset) else {
                return
            }
            memoryOffset = offset
        }

        let address = H256(from: rawAddress).toH160()
        var isCold = false
        if m.hardFork.isBerlin() {
            isCold = m.state.isCold(address: address)
            m.state.warm(address: address, isCold: isCold)
        }
        let cost = GasCost.extCodeCopyCost(hardFork: m.hardFork, isCold: isCold, size: size)
        if !m.gasRecordCost(cost: cost) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 4)
        if size == 0 {
            return
        }

        let codeOffset = rawCodeOffset.saturatingInt
        // The range was expanded above, so the copy cannot fail; bytes past the code are zero-filled.
        m.memory.writeData(offset: memoryOffset, size: size, from: m.handler.code(address: address), dataOffset: codeOffset)
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

    /// EIP-211: pushes the full return-data buffer size from Byzantium onward.
    static func returnDataSize(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isByzantium() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 0, push: 1) {
            return
        }

        if !m.gasRecordCost(cost: GasConstant.BASE) {
            return
        }

        let newValue = UInt64(m.returnData.buffer.count)
        m.stackPush(value: U256(from: newValue))
    }

    /// Copies call data into memory at the specified offset and size.
    static func callDataCopy(machine m: Machine) {
        if !m.verifyStack(pop: 3) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        // Peek the required values from the stack: memory offset, data offset, and size.
        let rawMemoryOffset = m.stackPeek(indexFromTop: 0)!
        let rawDataOffset = m.stackPeek(indexFromTop: 1)!
        let rawSize = m.stackPeek(indexFromTop: 2)!

        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // An empty range ignores the offset and does not expand memory.
        var memoryOffset = 0
        if size > 0 {
            guard let offset = m.getMemoryIntOrFail(rawMemoryOffset) else {
                return
            }
            memoryOffset = offset
        }

        let cost = GasCost.veryLowCopy(size: size)
        if !m.gasRecordCost(cost: cost) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 3)
        if size == 0 {
            return
        }

        let dataOffset = rawDataOffset.saturatingInt
        // The range was expanded above, so the copy cannot fail; bytes past the call data are zero-filled.
        m.memory.writeData(offset: memoryOffset, size: size, from: m.data, dataOffset: dataOffset)
    }

    /// EIP-211: copies return data without zero-padding; even an empty source range must be in bounds.
    static func returnDataCopy(machine m: Machine) {
        // Check hardfork
        guard m.hardFork.isByzantium() else {
            m.machineStatus = Machine.MachineStatus.Exit(Machine.ExitReason.Error(.HardForkNotActive))
            return
        }

        if !m.verifyStack(pop: 3) {
            return
        }

        // Stack size was verified above; these unwraps cannot fail.
        let rawMemoryOffset = m.stackPeek(indexFromTop: 0)!
        let rawDataOffset = m.stackPeek(indexFromTop: 1)!
        let rawSize = m.stackPeek(indexFromTop: 2)!
        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // An empty destination ignores its offset and does not expand memory.
        var memoryOffset = 0
        if size > 0 {
            guard let offset = m.getMemoryIntOrFail(rawMemoryOffset) else {
                return
            }
            memoryOffset = offset
        }

        if !m.gasRecordCost(cost: GasCost.veryLowCopy(size: size)) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Subtract only after bounding the offset, avoiding overflow in offset + size.
        guard let dataOffset = rawDataOffset.getInt,
              dataOffset <= m.returnData.buffer.count,
              size <= m.returnData.buffer.count - dataOffset
        else {
            m.machineStatus = .Exit(.Error(.OutOfOffset))
            return
        }

        m.stack.consume(count: 3)
        if size == 0 {
            return
        }

        // Both ranges are validated; writeData copies exactly size bytes without padding.
        m.memory.writeData(offset: memoryOffset, size: size, from: m.returnData.buffer, dataOffset: dataOffset)
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

    /// Appends a log with n topics and a snapshot of the specified memory range.
    static func log(machine m: Machine, n: Int) {
        if !m.verifyStack(pop: 2 + n) {
            return
        }

        if m.handler.isStatic() {
            m.machineStatus = .Exit(.Error(.WriteInStaticContext))
            return
        }

        // Stack depth was verified above; these unwraps cannot fail.
        let rawOffset = m.stackPeek(indexFromTop: 0)!
        let rawSize = m.stackPeek(indexFromTop: 1)!
        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }
        guard let cost = GasCost.logCost(size: size, n: n) else {
            m.machineStatus = .Exit(.Error(.OutOfGas))
            return
        }

        // An empty range ignores the offset and does not expand memory.
        var offset = 0
        if size > 0 {
            guard let memoryOffset = m.getMemoryIntOrFail(rawOffset) else {
                return
            }
            offset = memoryOffset
        }

        if !m.gasRecordCost(cost: cost) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: offset, size: size) else {
            return
        }

        // Stack depth was verified above; the nonempty range was expanded above.
        m.stack.consume(count: 2)
        let data = size > 0 ? m.memory.get(offset: offset, size: size) : []
        var topics: [H256] = []
        topics.reserveCapacity(n)
        for _ in 0 ..< n {
            // All n topics were included in the stack check.
            topics.append(m.stackPopH256()!)
        }

        if case .failure(let err) = m.handler.log(address: m.context.targetAddress, topics: topics, data: data) {
            m.machineStatus = .Exit(.Error(err))
        }
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

        guard let size = m.getMemoryIntOrFail(rawSize) else {
            return
        }

        // Per Yellow Paper, an empty input ignores the offset and does not expand memory.
        var memoryOffset = 0
        if size > 0 {
            guard let offset = m.getMemoryIntOrFail(rawMemoryOffset) else {
                return
            }
            memoryOffset = offset
        }

        let cost = GasCost.keccak256Cost(size: size)
        if !m.gasRecordCost(cost: cost) {
            return
        }

        guard m.resizeMemoryAndRecordGas(offset: memoryOffset, size: size) else {
            return
        }

        // Stack depth was verified above.
        m.stack.consume(count: 2)
        if size == 0 {
            // keccak256("") is a well-known constant.
            m.stackPush(value: U256(from: H256.KECCAK_EMPTY))
            return
        }

        // Memory expansion above guarantees the range is allocated before hashing.
        let hash = m.memory.withUnsafeBytes(offset: memoryOffset, size: size) { Keccak256.hash($0) }
        m.stackPush(value: U256(from: hash))
    }
}
