import PrimitiveTypes

final class ExecutionState {
    struct StorageKey: Hashable {
        let address: H160
        let key: H256
    }

    struct AccessedState {
        var addresses: Set<H160>
        var code: Set<H256>
        var storage: Set<StorageKey>
        var authority: [H160: H160]
    }

    /// Parent `ExecutionState`
    var parent: ExecutionState?
    /// Execution state accessed data
    var accessed: AccessedState
    /// Execution state call depth
    var depth: UInt16 = 0

    init() {
        self.accessed = AccessedState(
            addresses: Set<H160>(),
            code: Set<H256>(),
            storage: Set<StorageKey>(),
            authority: [H160: H160]()
        )
    }

    /// Determines if an address is considered "cold" (not previously accessed).
    ///
    /// An address is considered cold if it has not been accessed in the current execution context
    /// or any parent execution context. This is typically used for EIP-2929 gas cost calculations
    /// where accessing a cold address incurs higher gas costs than accessing a warm address.
    ///
    /// - Parameter address: The address to check for cold access status
    /// - Returns: `true` if the address is cold (not previously accessed), `false` if it's warm (previously accessed)
    func isCold(address: H160) -> Bool {
        if self.accessed.addresses.contains(address) {
            return false
        } else {
            return self.parent?.isCold(address: address) ?? true
        }
    }

    /// Marks an address as "warm" by adding it to the set of accessed addresses.
    ///
    /// In EIP-2929, addresses that have been accessed during transaction execution
    /// are considered "warm" and subsequent operations on these addresses consume
    /// less gas than "cold" operations on previously unaccessed addresses.
    ///
    /// - Parameter address: The address to mark as warm/accessed
    func warm(address: H160, isCold: Bool = true) {
        if isCold {
            self.accessed.addresses.insert(address)
        }
    }
}
