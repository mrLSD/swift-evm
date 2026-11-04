import PrimitiveTypes

/// Interpreter backend. Provides necessary information for `Machine` to execute `Opcode`.
public protocol Backend {
    /// Get environmental gas price.
    func gasPrice() -> U256
    /// Get environmental transaction origin.
    func origin() -> H160
    /// The canonical hash of block `number`, or `nil` when the environment has none. `BLOCKHASH` asks only for
    /// the 256 blocks before the current one, where a missing hash aborts execution.
    func blockHash(number: U256) -> H256?
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
    /// Get the account's own code hash: `keccak256` of `code(address:)`, or `KECCAK_EMPTY` for empty code and
    /// absent accounts. Serve it from stored or cached data; do not hash code on every call.
    func codeHash(address: H160) -> H256
    /// Whether the account has code, that is `codeHash(address:) != KECCAK_EMPTY`; `false` for absent accounts.
    /// Answer it from the account record or the code key without loading or hashing code.
    func hasCode(address: H160) -> Bool
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
