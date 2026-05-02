import Foundation

/// Aggregated per-run statistics.
///
/// Adds `skipped` over the Rust shape: Rust runs everything and treats unsupported tests as
/// failures, while we explicitly count tests that cannot yet be executed (transactor stub,
/// pre-Istanbul forks, etc.). Skipped tests are NOT counted as failures.
public struct TestExecutionResult: Sendable, Equatable {
    public var total: Int
    public var failed: Int
    public var skipped: Int
    public var slowTests: [TestBench]
    public var dumpedTransactions: [DumpedTransaction]

    public static let empty = TestExecutionResult(total: 0, failed: 0, skipped: 0, slowTests: [], dumpedTransactions: [])

    public mutating func merge(_ other: TestExecutionResult) {
        self.total += other.total
        self.failed += other.failed
        self.skipped += other.skipped
        self.slowTests.append(contentsOf: other.slowTests)
        self.dumpedTransactions.append(contentsOf: other.dumpedTransactions)
    }
}

/// One slow-test bench record. Populated when `--slow_tests` is set.
public struct TestBench: Sendable, Equatable {
    public let name: String
    public let spec: Spec
    public let elapsedNanos: UInt64
}

/// Placeholder for `--dump_successful_tx` output. Populated only after the transactor seam is
/// fleshed out (Phase 9+). Until then this stays empty.
public struct DumpedTransaction: Sendable, Equatable {
    public let spec: Spec
    public let testName: String
}
