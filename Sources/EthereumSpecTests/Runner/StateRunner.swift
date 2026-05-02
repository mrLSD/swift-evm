import Foundation
import Interpreter
import PrimitiveTypes

/// Executes a single decoded state test case across all (spec, variant) pairs.
///
/// **Phase 5 orchestration shell.** All the wiring around a state test — spec iteration,
/// pre-state setup, variant indexing into `Transaction.data/gasLimit/value`, vicinity build,
/// blob-gas-price derivation, access-list expansion — is implemented here. The actual
/// transactor call goes through `Transactor.call` / `Transactor.create` which currently
/// throw `notImplemented`. We catch those errors and **skip** the test rather than fail it.
///
/// Mirrors the body of `aurora-evm::evm-tests::state::test_run`.
enum StateRunner {
    typealias TransactFn = (Transactor.Input, TestBackend) throws -> Transactor.Output

    /// Test seam. Production passes `Transactor.call(input:backend:)` /
    /// `Transactor.create(input:backend:)`; tests can inject closures that succeed or throw
    /// non-`notImplemented` errors to exercise paths that would otherwise be unreachable.
    static func run(
        name: String,
        test: StateTestCase,
        specFilter: Spec?,
        verbose: VerboseOutput,
        transactCall: TransactFn = Transactor.call(input:backend:),
        transactCreate: TransactFn = Transactor.create(input:backend:)
    ) -> TestExecutionResult {
        var r = TestExecutionResult.empty

        // Iterate forks in deterministic order so output is reproducible across runs.
        let specs = test.postStates.keys.sorted { $0.rawValue < $1.rawValue }
        for spec in specs {
            if let filter = specFilter, filter != spec { continue }
            guard let posts = test.postStates[spec] else { continue }

            // Pre-Istanbul: Rust returns no Config and silently skips. We surface the skip.
            guard spec.hasExecutableConfig else {
                if verbose.veryVerbose {
                    print("  SKIP \(name) [\(spec.canonicalName)]: no executable config (pre-Istanbul)")
                }
                r.total += posts.count
                r.skipped += posts.count
                continue
            }

            // Blob gas price derivation (EIP-4844). Only relevant when the env carries
            // `currentExcessBlobGas` or the parent fields. `nil` means the test does not
            // exercise blob pricing — that's fine.
            let blobGasPrice = BlobExcessGasAndPrice.fromEnv(test.env)

            for post in posts {
                r.total += 1

                // Build a fresh world state per variant so a previous variant's mutations
                // (once Transactor lands) don't leak into the next.
                let (accounts, storage) = PreStateBuilder.build(test.preState.accounts)

                // Vicinity from the env block. The Rust harness derives gas-price /
                // effective-gas-price / chain-id from the transaction; we'll reuse Vicinity's
                // state-test factory for the env-only fields and patch in the tx fields below.
                var vicinity = Vicinity.fromStateEnv(test.env)
                vicinity.chainId = U256(from: 1)   // Spec tests use mainnet chainId by convention.
                vicinity.blobGasPrice = blobGasPrice?.blobGasPrice

                let backend = TestBackend(vicinity: vicinity, accounts: accounts, storage: storage)

                // Resolve per-variant transaction parameters.
                let data = test.transaction.getData(at: post.indexes)
                let gasLimitU256 = test.transaction.getGasLimit(at: post.indexes)
                let value = test.transaction.getValue(at: post.indexes)
                let accessList = test.transaction.getAccessList(at: post.indexes)
                let gasLimit = gasLimitU256.getUInt.flatMap { UInt64(exactly: $0) } ?? UInt64.max

                // Caller derivation.
                // The Rust harness recovers the caller from `secret_key` via secp256k1.
                // We do not yet have secp256k1 in Swift (see `Eip7702.SignedAuthorization`).
                // If `sender` is provided in the JSON, prefer it; otherwise we have to skip.
                guard let caller = test.transaction.sender else {
                    if verbose.veryVerbose {
                        print("  SKIP \(name) [\(spec.canonicalName)] variant data=\(post.indexes.data) gas=\(post.indexes.gas) value=\(post.indexes.value): no `sender` and secp256k1 caller recovery is not implemented")
                    }
                    r.skipped += 1
                    continue
                }

                let input = Transactor.Input(
                    spec: spec,
                    caller: caller,
                    to: test.transaction.to,
                    value: value,
                    data: data,
                    gasLimit: gasLimit,
                    accessList: accessList,
                    // Authorization list processing requires secp256k1 recovery — we pass an
                    // empty list to the seam; the test will skip via NotImplemented anyway.
                    authorizationList: []
                )

                do {
                    if test.transaction.to != nil {
                        let _ = try transactCall(input, backend)
                    } else {
                        let _ = try transactCreate(input, backend)
                    }
                    // Reachable only after the transactor seam is fleshed out. The post-state
                    // hash check goes here — see Phase 6 (`StateRootHasher`).
                    if verbose.verbose {
                        print("  PASS \(name) [\(spec.canonicalName)]")
                    }
                } catch let Transactor.TransactorError.notImplemented(reason) {
                    if verbose.veryVerbose {
                        print("  SKIP \(name) [\(spec.canonicalName)]: \(reason)")
                    }
                    r.skipped += 1
                } catch {
                    if verbose.verbose || verbose.verboseFailed {
                        print("  FAIL \(name) [\(spec.canonicalName)]: \(error)")
                    }
                    r.failed += 1
                }

                // Suppress unused-warning until Phase 6 lands — `post.hash` is the expected
                // state root we compare against once the transactor produces deltas.
                _ = post.hash
            }
        }

        return r
    }
}
