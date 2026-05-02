import Foundation

/// Print the test-run summary in the same format as Rust's `evm-tests`, with one addition:
/// a `SKIPPED` line. The Rust harness prints only `TOTAL` and `FAILED`, but we surface
/// `SKIPPED` because the Swift port has known stubs (transactor seam, precompiles) and
/// silently rolling those into the totals would obscure real progress.
func printSummary(_ result: TestExecutionResult) {
    print("")
    print("TOTAL: \(result.total)")
    print("FAILED: \(result.failed)")
    if result.skipped > 0 {
        print("SKIPPED: \(result.skipped)")
    }
    print("")
}

/// Print a slow-tests bench section. Sorted by descending elapsed time, mirroring Rust's
/// `tests_result.print_bench()` (which prints all benches collected during the run).
func printSlowTests(_ slowTests: [TestBench]) {
    guard !slowTests.isEmpty else { return }
    print("SLOW TESTS:")
    let sorted = slowTests.sorted { $0.elapsedNanos > $1.elapsedNanos }
    for bench in sorted {
        let ms = Double(bench.elapsedNanos) / 1_000_000
        print(String(format: "  %@ [%@]: %.2fms", bench.name, bench.spec.canonicalName, ms))
    }
    print("")
}

/// Write the `--dump_successful_tx` JSON artifact. Mirrors Rust's
/// `serde_json::to_string(&txs)` dump.
///
/// **Caveat**: dumps are populated only after `Transactor` produces a real call result.
/// While the seam is stubbed, this writes an empty JSON array `[]` so the file behavior is
/// honored end-to-end and CI plumbing that consumes the dump file does not break.
func writeDumpedTransactions(_ dumped: [DumpedTransaction], to url: URL) throws {
    let payload = dumped.map { tx -> [String: String] in
        [
            "spec": tx.spec.canonicalName,
            "name": tx.testName
        ]
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(payload)
    try data.write(to: url)
    print("TEST SUCCESSFUL TRANSACTIONS DUMPED TO: \(url.path) [\(dumped.count)]")
}
