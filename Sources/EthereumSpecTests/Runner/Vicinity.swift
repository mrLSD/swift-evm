import Foundation
import PrimitiveTypes

/// Block-level environment values for a single test execution.
///
/// Mirrors `aurora-evm::backend::MemoryVicinity` — the immutable side of the EVM context.
/// Mutable per-account state lives separately (see `TestBackend`).
struct Vicinity: Sendable {
    var gasPrice: U256
    var origin: H160
    var blockHashes: [H256]
    var blockNumber: U256
    var blockCoinbase: H160
    var blockTimestamp: U256
    var blockDifficulty: U256
    var blockGasLimit: U256
    var chainId: U256
    var blockBaseFeePerGas: U256
    var blockRandomness: H256?
    var blobGasPrice: U128?
    var blobHashes: [U256]

    /// Build a vicinity from a state-test `env` block (no transaction-level info).
    static func fromStateEnv(_ env: StateEnv) -> Vicinity {
        return Vicinity(
            gasPrice: U256.ZERO,
            origin: H160.ZERO,
            blockHashes: [],
            blockNumber: env.blockNumber,
            blockCoinbase: env.blockCoinbase,
            blockTimestamp: env.blockTimestamp,
            blockDifficulty: env.blockDifficulty,
            blockGasLimit: env.blockGasLimit,
            chainId: U256.ZERO,
            blockBaseFeePerGas: env.blockBaseFeePerGas,
            blockRandomness: env.random,
            blobGasPrice: nil,
            blobHashes: []
        )
    }

    /// Build a vicinity from a VM-test `exec` + `env` (gas price + origin come from `exec`).
    static func fromVm(env: StateEnv, exec: ExecutionTransaction) -> Vicinity {
        return Vicinity(
            gasPrice: exec.gasPrice,
            origin: exec.origin,
            blockHashes: [],
            blockNumber: env.blockNumber,
            blockCoinbase: env.blockCoinbase,
            blockTimestamp: env.blockTimestamp,
            blockDifficulty: env.blockDifficulty,
            blockGasLimit: env.blockGasLimit,
            chainId: U256.ZERO,
            blockBaseFeePerGas: exec.gasPrice,
            blockRandomness: env.random,
            blobGasPrice: nil,
            blobHashes: []
        )
    }
}
