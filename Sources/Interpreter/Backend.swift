import PrimitiveTypes

/// Interpreter backend. Provides necessary information for `Machine` to execute `Opcode`.
public protocol Backend {
    /// Gas  environmental gas price.
    func gasPrice() -> U256
    /// Get environmental transaction origin.
    func origin() -> H160
    /// Environmental block hash.
    func blockHash(number: U256) -> H256
    /// Environmental block number.
    func blockNumber() -> U256
    /// Environmental coinbase.
    func blockCoinbase() -> H160
    /// Environmental block timestamp.
    func blockTimestamp() -> U256
    /// Environmental block difficulty.
    func blockDifficulty() -> U256
    /// Get environmental block randomness.
    func blockRandomness() -> H256?
    /// Environmental block gas limit.
    func blockGasLimit() -> U256
    /// Environmental block base fee.
    func blockBaseFeePerGas() -> U256
    /// Environmental chain ID.
    func chainId() -> U256

    /// Whether account at address exists.
    func exists(address: H160) -> Bool
    /// Get basic account information.
    func basic(address: H160) -> BasicAccount
    /// Get account code.
    func code(address: H160) -> [UInt8]
    /// Get storage value of address at index.
    func storage(address: H160, index: H256) -> H256
    /// Check if the storage of the address is empty.
    func isEmptyStorage(address: H160) -> Bool
    /// Get original storage value of address at index, if available.
    func originalStorage(address: H160, index: H256) -> H256?
    /// CANCUN hard fork
    /// [EIP-4844]: Shard Blob Transactions
    /// [EIP-7516]: BLOBBASEFEE instruction
    func blobGasPrice() -> U128
    /// Get `blob_hash` from `blob_versioned_hashes` by index
    /// [EIP-4844]: BLOBHASH - https://eips.ethereum.org/EIPS/eip-4844#opcode-to-get-versioned-hashes
    func getBlobHash(index: UInt) -> U256?
}
