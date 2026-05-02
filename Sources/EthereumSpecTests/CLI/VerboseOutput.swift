import Foundation

/// Verbosity / reporting flags shared by the `vm` and `state` subcommands.
///
/// Mirrors the Rust `evm-tests::config::VerboseOutput` struct field-for-field so behavior
/// of `-v`, `-f`, `-w`, `-p`, `--slow_tests`, and `--dump_successful_tx` matches the
/// upstream harness.
struct VerboseOutput {
    let verbose: Bool
    let verboseFailed: Bool
    let veryVerbose: Bool
    let printState: Bool
    let printSlow: Bool
    let dumpTransactions: URL?
}
