@testable import EthereumSpecTests
import ArgumentParser
import Foundation
import Nimble
import Quick

// Path to the vendored state fixtures inside the test bundle. Resolved via `Bundle.module`
// so it works under both `swift test` (CWD = package root) and Xcode (CWD = build folder).
// The `resources: [.copy("Fixtures")]` directive on the test target in Package.swift copies
// the directory tree into the bundle at build time.
private let fixturesRoot = Bundle.module.resourceURL!
    .appendingPathComponent("Fixtures/state").path

final class StateCommandSpec: QuickSpec {
    override class func spec() {
        describe("state subcommand") {
            context("happy path") {
                it("walks the vendored fixtures, skips via Transactor, exits 0") {
                    let cmd = try! StateCommand.parse([fixturesRoot])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 1"))
                    expect(captured).to(contain("FAILED: 0"))
                    expect(captured).to(contain("SKIPPED: 1"))
                }
                it("filters by --spec") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--spec", "Cancun"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 1"))
                }
                it("excludes when --spec doesn't match the fixtures") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--spec", "Frontier"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 0"))
                }
                it("filters by --test-name (substring match)") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--test-name", "exampleSimple"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 1"))
                }
                it("excludes when --test-name doesn't match anything") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--test-name", "nope"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("TOTAL: 0"))
                }
                it("respects -v / --verbose") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "-v"])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("RUN for:"))
                }
                it("--slow_tests prints the slow-tests bench section (empty)") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--slow_tests"])
                    expect { try cmd.run() }.toNot(throwError())
                }
                it("--dump_successful_tx writes a dump file") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let dumpPath = tempDir.appendingPathComponent("dump.json").path
                    let cmd = try! StateCommand.parse([fixturesRoot, "--dump_successful_tx", dumpPath])
                    let captured = captureStandardOutput { try? cmd.run() }
                    expect(captured).to(contain("DUMPED TO"))
                    expect(FileManager.default.fileExists(atPath: dumpPath)).to(beTrue())
                }
                it("respects --enable-slow-tests") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--enable-slow-tests"])
                    expect { try cmd.run() }.toNot(throwError())
                }
            }

            context("error paths") {
                it("exits 2 when --spec is unknown") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--spec", "NotAFork"])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when a path does not exist") {
                    let cmd = try! StateCommand.parse(["/no/such/path/here"])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when a JSON file is unreadable (file-read error)") {
                    let tempDir = makeTempDirectory()
                    defer {
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
                    let cmd = try! StateCommand.parse([locked.path])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when a JSON file fails to parse") {
                    let tempDir = makeTempDirectory()
                    defer { try? FileManager.default.removeItem(at: tempDir) }
                    let bad = tempDir.appendingPathComponent("bad.json")
                    writeFixture("not valid json", to: bad)
                    let cmd = try! StateCommand.parse([bad.path])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
                it("exits 2 when --dump_successful_tx points at an unwritable directory") {
                    let cmd = try! StateCommand.parse([fixturesRoot, "--dump_successful_tx", "/no/such/dir/dump.json"])
                    expect { try cmd.run() }.to(throwError { (e: Error) in
                        expect((e as? ExitCode)?.rawValue).to(equal(2))
                    })
                }
            }
        }
    }
}

final class EthereumSpecTestsCommandSpec: QuickSpec {
    override class func spec() {
        describe("EthereumSpecTestsCommand root") {
            it("declares the vm and state subcommands") {
                let names = EthereumSpecTestsCommand.configuration.subcommands.map { $0.configuration.commandName }
                expect(names).to(contain("vm"))
                expect(names).to(contain("state"))
            }
            it("declares a non-empty version string") {
                expect(EthereumSpecTestsCommand.configuration.version).toNot(beEmpty())
            }
        }
    }
}
