@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class OutputSpec: QuickSpec {
    override class func spec() {
        describe("printSummary") {
            it("prints TOTAL and FAILED unconditionally") {
                let r = TestExecutionResult(total: 5, failed: 0, skipped: 0,
                                            slowTests: [], dumpedTransactions: [])
                let captured = captureStandardOutput { printSummary(r) }
                expect(captured).to(contain("TOTAL: 5"))
                expect(captured).to(contain("FAILED: 0"))
                expect(captured).toNot(contain("SKIPPED"))
            }
            it("prints SKIPPED only when count > 0") {
                let r = TestExecutionResult(total: 5, failed: 0, skipped: 3,
                                            slowTests: [], dumpedTransactions: [])
                let captured = captureStandardOutput { printSummary(r) }
                expect(captured).to(contain("TOTAL: 5"))
                expect(captured).to(contain("SKIPPED: 3"))
            }
        }

        describe("printSlowTests") {
            it("is silent when there are no slow tests") {
                let captured = captureStandardOutput { printSlowTests([]) }
                expect(captured).to(beEmpty())
            }
            it("sorts slow tests by descending elapsedNanos") {
                let benches: [TestBench] = [
                    TestBench(name: "A", spec: .Cancun, elapsedNanos: 1_000_000),
                    TestBench(name: "B", spec: .Prague, elapsedNanos: 5_000_000),
                    TestBench(name: "C", spec: .Berlin, elapsedNanos: 3_000_000)
                ]
                let captured = captureStandardOutput { printSlowTests(benches) }
                expect(captured).to(contain("SLOW TESTS:"))
                let bIdx = captured.range(of: "B")?.lowerBound
                let cIdx = captured.range(of: "C")?.lowerBound
                let aIdx = captured.range(of: "A")?.lowerBound
                expect(bIdx).toNot(beNil())
                expect(cIdx).toNot(beNil())
                expect(aIdx).toNot(beNil())
                expect(bIdx! < cIdx!).to(beTrue())
                expect(cIdx! < aIdx!).to(beTrue())
            }
            it("renders elapsed in milliseconds") {
                let benches = [TestBench(name: "X", spec: .Cancun, elapsedNanos: 12_345_000)]
                let captured = captureStandardOutput { printSlowTests(benches) }
                expect(captured).to(contain("12.35ms"))
            }
        }

        describe("writeDumpedTransactions") {
            it("writes an empty array when there are no dumped transactions") {
                let tempDir = makeTempDirectory()
                defer { try? FileManager.default.removeItem(at: tempDir) }
                let url = tempDir.appendingPathComponent("dump.json")
                let captured = captureStandardOutput {
                    try? writeDumpedTransactions([], to: url)
                }
                expect(FileManager.default.fileExists(atPath: url.path)).to(beTrue())
                let data = try! Data(contentsOf: url)
                let json = try! JSONSerialization.jsonObject(with: data) as! [Any]
                expect(json).to(beEmpty())
                expect(captured).to(contain("DUMPED TO"))
                expect(captured).to(contain("[0]"))
            }
            it("writes the spec/name fields for each dumped transaction") {
                let tempDir = makeTempDirectory()
                defer { try? FileManager.default.removeItem(at: tempDir) }
                let url = tempDir.appendingPathComponent("dump.json")
                let dumped = [
                    DumpedTransaction(spec: .Cancun, testName: "alpha"),
                    DumpedTransaction(spec: .Prague, testName: "beta")
                ]
                _ = captureStandardOutput { try? writeDumpedTransactions(dumped, to: url) }
                let data = try! Data(contentsOf: url)
                let json = try! JSONSerialization.jsonObject(with: data) as! [[String: String]]
                expect(json.count).to(equal(2))
                expect(json[0]["spec"]).to(equal("Cancun"))
                expect(json[0]["name"]).to(equal("alpha"))
                expect(json[1]["spec"]).to(equal("Prague"))
                expect(json[1]["name"]).to(equal("beta"))
            }
            it("propagates a write error to the caller") {
                let url = URL(fileURLWithPath: "/no/such/dir/dump.json")
                expect { try writeDumpedTransactions([], to: url) }.to(throwError())
            }
        }
    }
}
