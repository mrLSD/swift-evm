@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class FileWalkerSpec: QuickSpec {
    override class func spec() {
        describe("FileWalker type") {
            context("shortName") {
                it("strips a GeneralStateTests prefix") {
                    expect(FileWalker.shortName("/x/GeneralStateTests/foo/bar.json"))
                        .to(equal("foo/bar.json"))
                }
                it("strips a VMTests prefix") {
                    expect(FileWalker.shortName("/x/VMTests/foo/bar.json"))
                        .to(equal("foo/bar.json"))
                }
                it("returns the path unchanged when no prefix matches") {
                    expect(FileWalker.shortName("/abs/path/file.json"))
                        .to(equal("/abs/path/file.json"))
                }
            }

            context("enumerateJSON") {
                it("returns the path itself when given a single .json file") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let f = tempDir.appendingPathComponent("a.json")
                    writeFixture("{}", to: f)
                    expect(FileWalker.enumerateJSON(at: f.path)).to(equal([f.path]))
                }
                it("returns [] when given a non-.json file") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let f = tempDir.appendingPathComponent("a.txt")
                    writeFixture("hello", to: f)
                    expect(FileWalker.enumerateJSON(at: f.path)).to(beEmpty())
                }
                it("returns [] when the path does not exist") {
                    expect(FileWalker.enumerateJSON(at: "/no/such/path/here")).to(beEmpty())
                }
                it("recursively enumerates *.json files inside a directory") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let nested = tempDir.appendingPathComponent("sub")
                    try! FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
                    writeFixture("{}", to: tempDir.appendingPathComponent("a.json"))
                    writeFixture("{}", to: nested.appendingPathComponent("b.json"))
                    writeFixture("hello", to: tempDir.appendingPathComponent("c.txt"))
                    let files = FileWalker.enumerateJSON(at: tempDir.path).sorted()
                    expect(files.count).to(equal(2))
                    expect(files.contains(where: { $0.hasSuffix("a.json") })).to(beTrue())
                    expect(files.contains(where: { $0.hasSuffix("sub/b.json") })).to(beTrue())
                }
                it("ignores entries whose name starts with '.'") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let hidden = tempDir.appendingPathComponent(".hidden.json")
                    writeFixture("{}", to: hidden)
                    writeFixture("{}", to: tempDir.appendingPathComponent("visible.json"))
                    let files = FileWalker.enumerateJSON(at: tempDir.path)
                    expect(files.count).to(equal(1))
                    expect(files.first?.hasSuffix("visible.json")).to(beTrue())
                }
                it("skips files whose path matches the skip-list") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let dir = tempDir.appendingPathComponent("stTransactionTest")
                    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    writeFixture("{}", to: dir.appendingPathComponent("ValueOverflow.json"))
                    writeFixture("{}", to: dir.appendingPathComponent("OtherCase.json"))
                    let files = FileWalker.enumerateJSON(at: tempDir.path)
                    expect(files.count).to(equal(1))
                    expect(files.first?.hasSuffix("OtherCase.json")).to(beTrue())
                }
                it("skips an entire skip-listed root directory") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let dir = tempDir.appendingPathComponent("stTransactionTest")
                    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let nested = dir.appendingPathComponent("ValueOverflow")
                    try! FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
                    writeFixture("{}", to: nested.appendingPathComponent("a.json"))
                    let files = FileWalker.enumerateJSON(at: dir.path)
                    expect(files).to(beEmpty())
                }
                it("includes slow-test files when enableSlowTests is true") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let dir = tempDir.appendingPathComponent("stTimeConsuming")
                    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let f = dir.appendingPathComponent("static_Call50000_sha256.json")
                    writeFixture("{}", to: f)
                    expect(FileWalker.enumerateJSON(at: tempDir.path)).to(beEmpty())
                    expect(FileWalker.enumerateJSON(at: tempDir.path, enableSlowTests: true).count).to(equal(1))
                }
            }
        }
    }
}
