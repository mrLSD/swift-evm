@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class TestExecutionResultSpec: QuickSpec {
    override class func spec() {
        describe("TestExecutionResult type") {
            context("empty") {
                it("zeroes every counter and array") {
                    let r = TestExecutionResult.empty
                    expect(r.total).to(equal(0))
                    expect(r.failed).to(equal(0))
                    expect(r.skipped).to(equal(0))
                    expect(r.slowTests).to(beEmpty())
                    expect(r.dumpedTransactions).to(beEmpty())
                }
            }
            context("merge") {
                it("sums the integer counters") {
                    var a = TestExecutionResult(total: 1, failed: 0, skipped: 1, slowTests: [], dumpedTransactions: [])
                    let b = TestExecutionResult(total: 5, failed: 2, skipped: 3, slowTests: [], dumpedTransactions: [])
                    a.merge(b)
                    expect(a.total).to(equal(6))
                    expect(a.failed).to(equal(2))
                    expect(a.skipped).to(equal(4))
                }
                it("appends slowTests and dumpedTransactions in order") {
                    let bench1 = TestBench(name: "t1", spec: .Cancun, elapsedNanos: 100)
                    let bench2 = TestBench(name: "t2", spec: .Prague, elapsedNanos: 200)
                    let dump1 = DumpedTransaction(spec: .Cancun, testName: "d1")
                    let dump2 = DumpedTransaction(spec: .Prague, testName: "d2")

                    var a = TestExecutionResult(total: 0, failed: 0, skipped: 0, slowTests: [bench1], dumpedTransactions: [dump1])
                    let b = TestExecutionResult(total: 0, failed: 0, skipped: 0, slowTests: [bench2], dumpedTransactions: [dump2])
                    a.merge(b)
                    expect(a.slowTests.map(\.name)).to(equal(["t1", "t2"]))
                    expect(a.dumpedTransactions.map(\.testName)).to(equal(["d1", "d2"]))
                }
                it("is associative under repeated merge") {
                    var aggregate = TestExecutionResult.empty
                    for _ in 0..<5 {
                        aggregate.merge(TestExecutionResult(total: 1, failed: 0, skipped: 1, slowTests: [], dumpedTransactions: []))
                    }
                    expect(aggregate.total).to(equal(5))
                    expect(aggregate.skipped).to(equal(5))
                }
            }
        }

        describe("TestBench type") {
            it("stores name / spec / elapsedNanos verbatim") {
                let b = TestBench(name: "t", spec: .Cancun, elapsedNanos: 42)
                expect(b.name).to(equal("t"))
                expect(b.spec).to(equal(Spec.Cancun))
                expect(b.elapsedNanos).to(equal(42))
            }
        }

        describe("DumpedTransaction type") {
            it("stores spec / testName verbatim") {
                let d = DumpedTransaction(spec: .Prague, testName: "n")
                expect(d.spec).to(equal(Spec.Prague))
                expect(d.testName).to(equal("n"))
            }
        }
    }
}
