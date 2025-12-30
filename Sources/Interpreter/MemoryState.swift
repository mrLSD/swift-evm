import PrimitiveTypes

/// EVM memory state struct. This struct is used to track the state of the execution context, accessed data and storages during execution.
public class MemoryState {
    let backend: Backend

    /// State metadata. Represents the metadata of the execution context during all execution flow.
    var metadata: Metadata

    /// State logs list. This list is used to store logs generated during execution and can be used for various purposes such as event emission, debugging, etc.
    var logs: [Log] = []

    /// Parent State reference. This reference is used to track the parent state during execution and
    /// can be used for various purposes such as reverting state changes, etc.
    weak var parent: MemoryState?

    /// Accounts mapping. This mapping is used to store the state of accounts during execution and can be used for various purposes such as balance tracking, nonce tracking, etc.
    var accounts: [H160: StateAccount] = [:]

    /// Storages mapping. This mapping is used to store the state of storage slots during execution and can be used for various purposes such as storage tracking, etc.
    var storages: [Storage: H256] = [:]

    /// TStorages  mapping. This mapping is used to store the state of TStorage slots during execution.
    var tstorages: [Storage: H256] = [:]

    /// Deleted accounts set. This set is used to track deleted accounts during execution and can be used for various purposes such as reverting state changes, etc.
    var deletes: Set<H160> = .init()

    /// Created accounts set. This set is used to track created accounts during execution and can be used for various purposes such as reverting state changes, etc.
    var creates: Set<H160> = .init()

    /// Struct to store metadata of the execution context. This struct is used to track the state of the execution context
    public struct Metadata {
        /// EVM id static call flag. This flag indicates whether the current execution context is a static call or not.
        /// A static call is a call that does not allow state modifications and is used for read-only operations. This flag
        /// can be used to enforce restrictions on certain operations that are not allowed in static calls, such as modifying
        /// storage, emitting events, etc.
        let isStatic: Bool = false

        /// Optional depth of the call stack. This can be used to track the depth of nested calls and can be useful
        /// for various purposes such as gas calculation, access control, etc.
        let depth: UInt? = nil

        /// Optional accessed data struct. This struct can be used to track the state of accessed data during
        /// execution and can be used for various purposes such as gas calculation, access control, etc.
        /// The presence of this struct indicates that the current execution context is a Berlin hard fork or later, where
        /// access lists are introduced.
        let accessed: Accessed?

        /// Initialize `Metadata` with predefined static call flag and optional depth.
        public init(hardFork: HardFork) {
            self.accessed = hardFork.isBerlin() ? Accessed() : nil
        }
    }

    /// Struct to store accessed addresses, storages and authority list during execution. This struct is used to track the state of accessed data
    /// during execution and can be used for various purposes such as gas calculation, access control, etc.
    public struct Accessed {
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
        public init(accessedAddresses: Set<H160>, accessedStorage: Set<Storage>, authority: [H160: H160]) {
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
        mutating func accessAddresses<I: IteratorProtocol>(_ addresses: inout I) where I.Element == H160 {
            while let address = addresses.next() {
                self.addresses.insert(address)
            }
        }

        /// Add storages data to the accessed storage list.
        mutating func addStorages<I: IteratorProtocol>(_ storages: inout I) where I.Element == Storage {
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
    }

    /// Struct to store accessed storage key-value pairs. This struct is used to track the state of accessed storage during execution
    /// and can be used for various purposes such as gas calculation, access control, etc.
    public struct Storage: Hashable {
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
    public init(metadata: Metadata, backend: Backend) {
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

    /// Check if account is known to be empty. This function is used to check if an account is known to be empty (i.e., has zero balance, zero nonce and empty code).
    public func knownEmpty(_ address: H160) -> Bool? {
        if let account = knownAccount(address) {
            if account.basic.balance != U256.ZERO || account.basic.nonce != U256.ZERO {
                return false
            }

            if let code = account.code {
                return code.isEmpty
            }
        }
        return nil
    }

    /// Get known storage value by address and key. This function is used to retrieve the value of a storage slot by its address and key.
    public func knownStorage(address: H160, key: H256) -> H256? {
        if let value = storages[Storage(address: address, index: key)] {
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
        return recursiveIsCold { accessed in accessed.storage.contains(Storage(address: address, index: key)) }
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

    /// Get mutable account from current or parent state and cache it if needed to known account. This function is used to retrieve a mutable reference to an account by its address.
    public func accountMut(address: H160) -> StateAccount {
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
        let account = accountMut(address: address)
        if account.basic.nonce >= U256(from: UInt64.max) {
            return .failure(Machine.ExitError.MaxNonce)
        }
        account.basic.incNonce()

        return .success(())
    }

    /// Set storage value for address and key.
    public func setStorage(address: H160, key: H256, value: H256) {
        // Using Storage(key:address, value:key) as composite key.
        storages[Storage(address: address, index: key)] = value
    }

    /// Reset storage for address and mark account as reset.
    public func resetStorage(address: H160) {
        let keysToRemove = storages.keys.filter { $0.address == address }

        for key in keysToRemove {
            storages.removeValue(forKey: key)
        }

        accountMut(address: address).reset = true
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
        accountMut(address: address).code = code
    }
}
