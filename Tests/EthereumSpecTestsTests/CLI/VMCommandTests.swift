@testable import EthereumSpecTests
import ArgumentParser
import Foundation
import Nimble
import Quick

// Path to the vendored VM fixtures inside the test bundle. Resolved via `Bundle.module`
// so it works under both `swift test` (CWD = package root) and Xcode (CWD = build folder).
// The `resources: [.copy("Fixtures")]` directive on the test target in Package.swift copies
// the directory tree into the bundle at build time.
private let fixturesRoot = Bundle.module.resourceURL!
    .appendingPathComponent("Fixtures/vm").path

final class VMCommandSpec: QuickSpec {
    override class func spec() {
        describe("vm subcommand") {
            context("happy path") {
                it("walks the vendored fixtures and exits 0") {
                    let cmd = try! VMCommand.parse([fixturesRoot])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 1"))
                    expect(captured).to(contain("FAILED: 0"))
                }
                it("respects -v / --verbose") {
                    let cmd = try! VMCommand.parse([fixturesRoot, "-v"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("RUN for:"))
                }
                it("respects --enable-slow-tests") {
                    let cmd = try! VMCommand.parse([fixturesRoot, "--enable-slow-tests"])
                    expect { try cmd.run() }.toNot(throwError())
                }
            }

            context("error paths") {
                it("exits 2 when a path does not exist") {
                    let cmd = try! VMCommand.parse(["/no/such/path/here"])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when a JSON file is unreadable (file-read error)") {
                    let tempDir = makeTempDirectory()
                    defer {
                        // Restore permissions before cleanup so removeItem succeeds.
                        for entry in (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? [] {
                            try? FileManager.default.setAttributes(
                                [.posixPermissions: 0o644],
                                ofItemAtPath: tempDir.appendingPathComponent(entry).path
                            )
                        }
                        try? FileManager.default.removeItem(at: tempDir)
                    }
                    let locked = tempDir.appendingPathComponent("locked.json")
                    writeFixture("{}", to: locked)
                    try! FileManager.default.setAttributes(
                        [.posixPermissions: 0o000], ofItemAtPath: locked.path
                    )
                    let cmd = try! VMCommand.parse([locked.path])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when a JSON file fails to parse") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let bad = tempDir.appendingPathComponent("bad.json")
                    writeFixture("not valid json", to: bad)
                    let cmd = try! VMCommand.parse([bad.path])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 1 when at least one test fails (failed > 0)") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    // VM test that asserts a non-matching gas-left → forces FAIL.
                    let json = #"""
                    {
                      "fail-on-gas": {
                        "callcreates": [],
                        "env": {
                          "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
                          "currentDifficulty": "0x0",
                          "currentGasLimit": "0x0",
                          "currentNumber": "0x0",
                          "currentTimestamp": "0x0"
                        },
                        "exec": {
                          "address": "0x0000000000000000000000000000000000000001",
                          "caller":  "0x0000000000000000000000000000000000000002",
                          "code":    "0x00",
                          "data":    "0x",
                          "gas":     "0x10",
                          "gasPrice":"0x01",
                          "origin":  "0x0000000000000000000000000000000000000003",
                          "value":   "0x00"
                        },
                        "gas":  "0xff",
                        "pre":  {},
                        "post": {}
                      }
                    }
                    """#
                    let f = tempDir.appendingPathComponent("fail.json")
                    writeFixture(json, to: f)
                    let cmd = try! VMCommand.parse([f.path])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(1))
                    })
                }
            }
        }
    }
}
