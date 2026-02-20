import PrimitiveTypes

/// EVM memory state struct. This struct is used to track the state of the execution context, accessed data and storages during execution.
public class MemoryState {
    /// Environment backend. This backend is used to retrieve account data and other information from the environment during execution.
    let backend: any Backend

    /// State metadata. Represents the metadata of the execution context during all execution flow.
    var metadata: Metadata

    /// State logs list. This list is used to store logs generated during execution and can be used for various purposes such as event emission, debugging, etc.
    var logs: [Log] = []

    /// Parent State reference. This reference is used to track the parent state during execution and
    /// can be used for various purposes such as reverting state changes, etc.
    /// - Note: We can't use `weak` reference here because parent state can be deallocated during execution and we need to keep it alive until the end of execution.
    var parent: MemoryState?

    /// Accounts mapping. This mapping is used to store the state of accounts during execution and can be used for various purposes such as balance tracking, nonce tracking, etc.
    var accounts: [H160: StateAccount] = [:]

    /// Storages mapping. This mapping is used to store the state of storage slots during execution and can be used for various purposes such as storage tracking, etc.
    var storages: [H160: [H256: H256]] = [:]

    /// TStorages  mapping. This mapping is used to store the state of TStorage slots during execution.
    var tstorages: [H160: [H256: H256]] = [:]

    /// Deleted accounts set. This set is used to track deleted accounts during execution and can be used for various purposes such as reverting state changes, etc.
    var deletes: Set<H160> = .init()

    /// Created accounts set. This set is used to track created accounts during execution and can be used for various purposes such as reverting state changes, etc.
    var creates: Set<H160> = .init()

    /// Struct to store metadata of the execution context. This struct is used to track the state of the execution context
    public struct Metadata: Equatable, Sendable {
        /// State gasometer.
        private(set) var gasometer: Gas

        /// EVM id static call flag. This flag indicates whether the current execution context is a static call or not.
        /// A static call is a call that does not allow state modifications and is used for read-only operations. This flag
        /// can be used to enforce restrictions on certain operations that are not allowed in static calls, such as modifying
        /// storage, emitting events, etc.
        let isStatic: Bool

        /// Optional depth of the call stack. This can be used to track the depth of nested calls and can be useful
        /// for various purposes such as gas calculation, access control, etc.
        let depth: UInt?

        /// Optional accessed data struct. This struct can be used to track the state of accessed data during
        /// execution and can be used for various purposes such as gas calculation, access control, etc.
        /// The presence of this struct indicates that the current execution context is a Berlin hard fork or later, where
        /// access lists are introduced.
        var accessed: Accessed?

        /// Initialize `Metadata` with predefined static call flag and optional depth.
        public init(gasometer: Gas, hardFork: HardFork) {
            self.accessed = hardFork.isBerlin() ? Accessed() : nil
            self.gasometer = gasometer
            self.depth = nil
            self.isStatic = false
        }

        /// Initialize `Metadata` with predefined gasometer, static call flag, optional depth and optional accessed data struct.
        public init(gasometer: Gas, isStatic: Bool, depth: UInt?, accessed: Accessed?) {
            self.gasometer = gasometer
            self.depth = depth
            self.isStatic = isStatic
            self.accessed = accessed
        }

        /// Swallow commit implements part of logic for execution `exitCommit`:
        /// - Record opcode stipend.
        /// - Record an explicit refund.
        /// - Merge warmed accounts and storages
        public mutating func swallowCommit(from other: borrowing Self) {
            gasometer.recordStipend(stipend: other.gasometer.remaining)
            gasometer.recordRefund(refund: other.gasometer.refunded)

            // Optimized merge warmed accounts and storages
            if let otherAccessed = other.accessed {
                if accessed == nil {
                    accessed = otherAccessed
                } else {
                    accessed?.merge(with: otherAccessed)
                }
            }
        }

        /// Swallow revert implements part of logic for execution  `exitRevert`:
        /// - Record opcode stipend.
        public mutating func swallowRevert(from other: Self) {
            gasometer.recordStipend(stipend: other.gasometer.remaining)
        }

        /// Create a child `Metadata` with a fresh gasometer, propagated static flag, incremented depth, and reset
        /// accessed data when present.
        public func spitChild(gasLimit: UInt64, isStatic: Bool) -> Self {
            return Self(
                gasometer: Gas(limit: gasLimit),
                isStatic: isStatic || self.isStatic,
                depth: depth.map { $0 + 1 } ?? 0,
                accessed: accessed.map { _ in Accessed() }
            )
        }

        /// Mark a single address as accessed, if access lists are enabled.
        public mutating func accessAddress(_ address: H160) {
            accessed?.setAccessAddress(address)
        }

        /// Mark multiple addresses as accessed, if access lists are enabled.
        public mutating func accessAddresses<I: IteratorProtocol>(_ addresses: inout I)
            where I.Element == H160
        {
            accessed?.accessAddresses(&addresses)
        }

        /// Mark a single storage slot as accessed, if access lists are enabled.
        public mutating func accessStorage(address: H160, key: H256) {
            accessed?.storage.insert(Storage(address: address, index: key))
        }

        /// Mark multiple storage slots as accessed, if access lists are enabled.
        public mutating func accessStorages<I: IteratorProtocol>(_ storages: inout I)
            where I.Element == Storage
        {
            accessed?.addStorages(&storages)
        }

        /// Read accessed data (used for gas calculation logic).
        public func accessedData() -> Accessed? {
            return accessed
        }

        /// Add authority to accessed list (EIP\-7702).
        public mutating func addAuthority(authority: H160, address: H160) {
            accessed?.addAuthority(authority: authority, address: address)
        }

        /// Remove authority from accessed list (EIP\-7702).
        public mutating func removeAuthority(_ authority: H160) {
            accessed?.removeAuthority(authority)
        }
    }

    /// Struct to store accessed addresses, storages and authority list during execution. This struct is used to track the state of accessed data
    /// during execution and can be used for various purposes such as gas calculation, access control, etc.
    public struct Accessed: Equatable, Sendable {
        /// Accessed addresses list. Contains addresses of accessed accounts.
        var addresses: Set<H160>

        /// Accessed storage list. Contains key-value pairs of accessed storage slots.
        var storage: Set<Storage>

        /// Accessed authority list for EIP-7702. Maps authority address to target address.
        var authority: [H160: H160]

        /// Initialize `Accessed` with empty data.
        public init() {
            self.addresses = Set<H160>()
            self.storage = Set<Storage>()
            self.authority = [H160: H160]()
        }

        /// Initialize `Accessed` with predefined accessed addresses, storages and authority list.
        public init(
            accessedAddresses: Set<H160>, accessedStorage: Set<Storage>, authority: [H160: H160]
        ) {
            self.addresses = accessedAddresses
            self.storage = accessedStorage
            self.authority = authority
        }

        /// Add address to the accessed address list.
        mutating func setAccessAddress(_ address: H160) {
            addresses.insert(address)
        }

        /// Add addresses to the accessed address list.
        mutating func accessAddresses<S: Sequence>(_ addresses: S) where S.Element == H160 {
            self.addresses.formUnion(addresses)
        }

        /// Add addresses to the accessed address list.
        mutating func accessAddresses<I: IteratorProtocol>(_ addresses: inout I)
            where I.Element == H160
        {
            while let address = addresses.next() {
                self.addresses.insert(address)
            }
        }

        /// Add storages data to the accessed storage list.
        mutating func addStorages<I: IteratorProtocol>(_ storages: inout I)
            where I.Element == Storage
        {
            while let storage = storages.next() {
                self.storage.insert(storage)
            }
        }

        /// Add authority to the accessed authority list (EIP-7702).
        mutating func addAuthority(authority: H160, address: H160) {
            self.authority[authority] = address
        }

        /// Remove authority from the accessed authority list (EIP-7702).
        mutating func removeAuthority(_ authority: H160) {
            self.authority.removeValue(forKey: authority)
        }

        /// Get authority from the accessed authority list (EIP-7702).
        func getAuthorityTarget(_ authority: H160) -> H160? {
            return self.authority[authority]
        }

        /// Check if authority is in the accessed authority list (EIP-7702).
        func isAuthority(_ authority: H160) -> Bool {
            return self.authority.keys.contains(authority)
        }

        /// Merge accessed data with other accessed data.
        mutating func merge(with other: borrowing Accessed) {
            addresses.formUnion(other.addresses)
            storage.formUnion(other.storage)

            authority.merge(other.authority) { _, new in new }
        }
    }

    /// Struct to store accessed storage key-value pairs. This struct is used to track the state of accessed storage during execution
    /// and can be used for various purposes such as gas calculation, access control, etc.
    public struct Storage: Hashable, Equatable, Sendable {
        /// Address of accessed storage slot.
        var address: H160

        /// Index of accessed storage slot.
        var index: H256

        /// Initialize `Storage` with predefined key and value.
        public init(address: H160, index: H256) {
            self.address = address
            self.index = index
        }
    }

    /// Initialize `MemoryState` with predefined metadata.
    public init(gasLimit: UInt64, backend: any Backend, hardFork: HardFork) {
        self.metadata = Metadata(gasometer: Gas(limit: gasLimit), hardFork: hardFork)
        self.backend = backend
    }

    /// Initialize `MemoryState` with predefined metadata, backend.
    public init(metadata: Metadata, backend: any Backend) {
        self.metadata = metadata
        self.backend = backend
    }

    /// Get known account by address. This function is used to retrieve the state of an account by its address.
    /// It first checks the current state's accounts mapping, and if the account is not found, it recursively checks the
    /// parent state until it finds the account or reaches the top-level state.
    public func knownAccount(_ address: H160) -> StateAccount? {
        if let account = accounts[address] {
            return account
        }
        return parent?.knownAccount(address)
    }

    /// Get known basic account data by address. This function is used to retrieve the basic data of an account by its address.
    public func knownBasic(_ address: H160) -> BasicAccount? {
        return knownAccount(address)?.basic
    }

    /// Get known account code by address. This function is used to retrieve the code of an account by its address.
    public func knownCode(_ address: H160) -> [UInt8]? {
        return knownAccount(address)?.code
    }

    /// Get known storage value by address and key. This function is used to retrieve the value of a storage slot by its address and key.
    public func knownStorage(address: H160, key: H256) -> H256? {
        if let accountStorage = storages[address], let value = accountStorage[key] {
            return value
        }
        if let account = accounts[address], account.reset {
            return H256.ZERO
        }
        return parent?.knownStorage(address: address, key: key)
    }

    /// Get known original storage value by address. This function is used to retrieve the original value of a storage slot by its address.
    public func knownOriginalStorage(_ address: H160) -> H256? {
        if let account = accounts[address], account.reset {
            return H256.ZERO
        }
        return parent?.knownOriginalStorage(address)
    }

    /// Check is account address is cold by address.
    public func isCold(_ address: H160) -> Bool {
        return recursiveIsCold { accessed in accessed.addresses.contains(address) }
    }

    /// Check is storage slot is cold by address and key.
    public func isStorageCold(address: H160, key: H256) -> Bool {
        return recursiveIsCold { accessed in
            accessed.storage.contains(Storage(address: address, index: key))
        }
    }

    /// Check recursively if account or storage is cold.
    private func recursiveIsCold(_ f: (Accessed) -> Bool) -> Bool {
        let localIsAccessed = metadata.accessed.map(f) ?? false
        if localIsAccessed {
            return false
        }
        return parent?.recursiveIsCold(f) ?? true
    }

    /// Check is account address marked as deleted in current or parent state.
    public func isDeleted(_ address: H160) -> Bool {
        if deletes.contains(address) {
            return true
        }
        return parent?.isDeleted(address) ?? false
    }

    /// Get account by address and cache it.
    public func getAccountAndTouch(_ address: H160) -> StateAccount {
        if let existingAccount = accounts[address] {
            return existingAccount
        }

        let account: StateAccount

        // We already checked current state for known account. So we can check directly from parent states for known account.
        if let knownAccount = parent?.knownAccount(address) {
            // We actually clone known account here to avoid mutating parent state. This is important for correct handling account state.
            // And we clear `reset` flag to avoid incorrect handling state.
            account = StateAccount(
                basic: knownAccount.basic,
                code: knownAccount.code,
                reset: false
            )
        } else {
            // Get account data from backend if account is not known in current state or parent states.
            account = StateAccount(
                basic: backend.basic(address: address),
                code: nil,
                reset: false
            )
        }

        accounts[address] = account
        return account
    }

    /// Increment nonce for address in the state
    public func incNonce(address: H160) -> Result<Void, Machine.ExitError> {
        let account = getAccountAndTouch(address)
        if account.basic.nonce >= U256(from: UInt64.max) {
            return .failure(Machine.ExitError.MaxNonce)
        }
        accounts[address]?.basic.incNonce()

        return .success(())
    }

    /// Set storage value for address and key.
    public func setStorage(address: H160, key: H256, value: H256) {
        if storages[address] == nil {
            storages[address] = [:]
        }
        storages[address]?[key] = value
    }

    /// Reset storage for address and mark account as reset.
    public func resetStorage(address: H160) {
        storages.removeValue(forKey: address)
        _ = getAccountAndTouch(address)

        accounts[address]?.reset = true
    }

    /// Append log entry.
    public func log(address: H160, topics: [H256], data: [UInt8]) {
        logs.append(Log(address: address, topics: topics, data: data))
    }

    /// Mark account as deleted.
    public func setDeleted(address: H160) {
        deletes.insert(address)
    }

    /// Mark account as created.
    public func setCreated(address: H160) {
        creates.insert(address)
    }

    /// Check if account was created in this or parent state.
    public func isCreated(_ address: H160) -> Bool {
        if creates.contains(address) {
            return true
        }
        return parent?.isCreated(address) ?? false
    }

    /// Set account code.
    public func setCode(address: H160, code: [UInt8]) {
        _ = getAccountAndTouch(address)
        accounts[address]?.code = code
    }

    /// Check if the account at the given address is empty.
    /// An account is empty if its balance is zero, its nonce is zero, and its code is empty.
    ///
    /// - Parameter address: The address to check.
    /// - Returns: `true` if the account is empty, `false` otherwise.
    public func isEmpty(address: H160) -> Bool {
        if let account = knownAccount(address) {
            if !account.basic.balance.isZero || !account.basic.nonce.isZero {
                return false
            }

            if let code = account.code {
                return code.isEmpty
            }
            return backend.code(address: address).isEmpty
        }

        // If not known locally, fetch data from the environment backend.
        let basic = backend.basic(address: address)

        // Account is empty if: balance == 0 AND nonce == 0 AND code is empty.
        return basic.balance.isZero &&
            basic.nonce.isZero &&
            backend.code(address: address).isEmpty
    }

    /// Internal helper to swap the entire state data between two instances.
    /// This is an O(1) operation for collections due to Swift's Copy-on-Write implementation.
    private func swapState(with other: MemoryState) {
        swap(&logs, &other.logs)
        swap(&accounts, &other.accounts)
        swap(&storages, &other.storages)
        swap(&tstorages, &other.tstorages)
        swap(&deletes, &other.deletes)
        swap(&creates, &other.creates)
        swap(&parent, &other.parent)
        swap(&metadata, &other.metadata)
    }

    /// Enter a new `substate` by creating a child `MemoryState` with the current state as its parent.
    /// The current state data is "pushed" into a parent state, and 'self' becomes a fresh substate.
    public func enter(gasLimit: UInt64, isStatic: Bool) {
        let oldState = MemoryState(metadata: metadata, backend: backend)

        // Push current data to oldState
        swapState(with: oldState)

        // Re-establish the link: self is now the child of oldState
        metadata = metadata.spitChild(gasLimit: gasLimit, isStatic: isStatic)
        parent = oldState
    }

    /// Exit commit represents successful execution of the `substate`.
    ///
    /// It includes:
    /// - swallow commit:
    ///   - gas recording
    ///   - warmed accesses merging
    /// - logs merging
    /// - for account existed from substate with reset flag, remove storages by keys
    /// - merge substate data: accounts, storages, tstorages, deletes, creates
    ///
    /// - Throws: `fatalError` if called on a root state.
    public func exitCommit() {
        guard let exited = parent else { fatalError("Cannot commit on root substate") }

        // 1. Swap back: 'self' becomes the parent, 'exited' variable holds the substate data
        swapState(with: exited)

        // Break the self-referencing cycle created by swapping parent pointers
        exited.parent = nil

        // 2. Process metadata (gas and warmed access lists)
        metadata.swallowCommit(from: exited.metadata)

        // 3. Merge logs
        logs.append(contentsOf: exited.logs)

        // 4. Handle Storage Resets
        // If an account in the substate has the 'reset' flag, we clear the storage
        // for that address in the parent state (which is now 'self').
        for (address, account) in exited.accounts {
            if account.reset {
                storages[address] = nil
            }
        }

        // 5. Merge substate data into current state
        // Merge Accounts
        accounts.merge(exited.accounts) { _, new in new }

        // Merge Storages (Dictionary of Dictionaries)
        for (address, subStorage) in exited.storages {
            if storages[address] == nil {
                storages[address] = subStorage
            } else {
                storages[address]?.merge(subStorage) { _, new in new }
            }
        }

        // Merge TStorages
        for (address, subTStorage) in exited.tstorages {
            if tstorages[address] == nil {
                tstorages[address] = subTStorage
            } else {
                tstorages[address]?.merge(subTStorage) { _, new in new }
            }
        }

        // Merge Sets
        deletes.formUnion(exited.deletes)
        creates.formUnion(exited.creates)

        // NOTE: Memory of 'exited' (the substate) is freed here as it leaves scope
    }

    /// Exit revert. Represents revert execution of the `substate`.
    ///
    /// - Throws: `fatalError` if called on a root state.
    public func exitRevert() {
        guard let exited = parent else { fatalError("Cannot revert on root substate") }

        // Swap back: restore parent data to 'self', substate moves to 'exited'
        swapState(with: exited)

        // Break the self-referencing cycle created by swapping parent pointers
        exited.parent = nil

        // Swallow only gas stipend from the reverted substate
        metadata.swallowRevert(from: exited.metadata)
    }

    /// Exit discard. Represents discard execution of the `substate`.
    ///
    /// - Throws: `fatalError` if called on a root state.
    public func exitDiscard() {
        guard let exited = parent else { fatalError("Cannot discard on root substate") }

        // Swap back: restore parent data to 'self'
        swapState(with: exited)

        // Break the self-referencing cycle created by swapping parent pointers
        exited.parent = nil
    }

    /// Transfer value between two accounts.
    /// - Returns: `Success` if the transfer is possible, or `OutOfFund` error.
    public func transfer(transfer: Transfer) -> Result<Void, Machine.ExitError> {
        let source = getAccountAndTouch(transfer.source)
        if source.basic.balance < transfer.value {
            return .failure(.OutOfFund)
        }
        // Transfer to self is allowed and should not change the state, so we can skip it.
        if transfer.source == transfer.target {
            return .success(())
        }

        accounts[transfer.source]?.basic.subBalance(transfer.value)

        _ = getAccountAndTouch(transfer.target)
        accounts[transfer.target]?.basic.addBalance(transfer.value)

        return .success(())
    }

    /// Withdraw value from an account.
    /// - Returns: `Success` if the withdrawal is possible, or `OutOfFund` error.
    public func withdraw(address: H160, value: U256) -> Result<Void, Machine.ExitError> {
        let source = getAccountAndTouch(address)
        if source.basic.balance < value {
            return .failure(.OutOfFund)
        }
        accounts[address]?.basic.subBalance(value)

        return .success(())
    }

    /// Deposit value into an account. Only needed for jsontests.
    public func deposit(address: H160, value: U256) {
        _ = getAccountAndTouch(address)
        accounts[address]?.basic.addBalance(value)
    }

    /// Reset account balance to zero.
    public func resetBalance(address: H160) {
        _ = getAccountAndTouch(address)
        accounts[address]?.basic.setBalance(U256.ZERO)
    }

    /// Mark account as touched by accessing it.
    public func touch(address: H160) {
        _ = getAccountAndTouch(address)
    }

    /// Get transient storage value for address and key.
    public func getTStorage(address: H160, key: H256) -> H256 {
        return knownTStorage(address: address, key: key) ?? .ZERO
    }

    /// Retrieve transient storage value recursively from current or parent states.
    public func knownTStorage(address: H160, key: H256) -> H256? {
        if let accountTStorage = tstorages[address], let value = accountTStorage[key] {
            return value
        }
        return parent?.knownTStorage(address: address, key: key)
    }

    /// Set transient storage value for address and key.
    public func setTStorage(address: H160, key: H256, value: H256) {
        if tstorages[address] == nil {
            tstorages[address] = [:]
        }
        tstorages[address]?[key] = value
    }

    // MARK: - EIP-7702 Authority Logic

    /// Get authority target from the current state. If it's `None`, look recursively in the parent state.
    public func getAuthorityTargetRecursive(authority: H160) -> H160? {
        if let target = metadata.accessed?.getAuthorityTarget(authority) {
            return target
        }
        return parent?.getAuthorityTargetRecursive(authority: authority)
    }

    /// EIP-7702: Check if the authority is cold.
    /// - Parameter address: The authority address to check.
    /// - Returns: `true` or `false` if the target is found and checked, otherwise `nil`.
    public func isAuthorityCold(address: H160) -> Bool? {
        return getAuthorityTarget(authority: address).map { isCold($0) }
    }

    /// Get authority target (EIP-7702) delegated address.
    ///
    /// First, it attempts to retrieve the authority target from the cache recursively
    /// through parent states. If not found in the cache, it retrieves the code for the
    /// authority address and checks if it's a delegation designator. If true, it adds
    /// the result to the cache and returns the delegated target address.
    ///
    /// - Parameter authority: The authority address.
    /// - Returns: The delegated target address, if found.
    public func getAuthorityTarget(authority: H160) -> H160? {
        // 1. Try to read from recursive cache
        if let targetAddress = getAuthorityTargetRecursive(authority: authority) {
            return targetAddress
        }

        // 2. If not found in cache, get the code for the authority address.
        // This uses the 'code' method from the Backend implementation (local cache + backend).
        let authorityCode = code(address: authority)

        // 3. Check if the code represents a delegation designator (EIP-7702 logic).
        if let target = Authorization.getDelegatedAddress(authorityCode) {
            // Add the found target to the local substate metadata cache.
            metadata.addAuthority(authority: authority, address: target)
            return target
        }

        return nil
    }
}

extension MemoryState: Backend {
    // MARK: - Environmental Information (Proxied to Backend)

    public func gasPrice() -> U256 {
        return backend.gasPrice()
    }

    public func origin() -> H160 {
        return backend.origin()
    }

    public func blockHash(number: U256) -> H256 {
        return backend.blockHash(number: number)
    }

    public func blockNumber() -> U256 {
        return backend.blockNumber()
    }

    public func blockCoinbase() -> H160 {
        return backend.blockCoinbase()
    }

    public func blockTimestamp() -> U256 {
        return backend.blockTimestamp()
    }

    public func blockDifficulty() -> U256 {
        return backend.blockDifficulty()
    }

    public func blockRandomness() -> H256? {
        return backend.blockRandomness()
    }

    public func blockGasLimit() -> U256 {
        return backend.blockGasLimit()
    }

    public func blockBaseFeePerGas() -> U256 {
        return backend.blockBaseFeePerGas()
    }

    public func chainId() -> U256 {
        return backend.chainId()
    }

    public func blobGasPrice() -> U128 {
        return backend.blobGasPrice()
    }

    public func getBlobHash(index: UInt) -> U256? {
        return backend.getBlobHash(index: index)
    }

    // MARK: - State Information (Cache First, then Backend)

    public func exists(address: H160) -> Bool {
        return knownAccount(address) != nil || backend.exists(address: address)
    }

    public func basic(address: H160) -> BasicAccount {
        return knownBasic(address) ?? backend.basic(address: address)
    }

    public func code(address: H160) -> [UInt8] {
        return knownCode(address) ?? backend.code(address: address)
    }

    public func storage(address: H160, index: H256) -> H256 {
        return knownStorage(address: address, key: index) ?? backend.storage(address: address, index: index)
    }

    public func isEmptyStorage(address: H160) -> Bool {
        return backend.isEmptyStorage(address: address)
    }

    public func originalStorage(address: H160, index: H256) -> H256? {
        if let value = knownOriginalStorage(address) {
            return value
        }
        return backend.originalStorage(address: address, index: index)
    }
}
