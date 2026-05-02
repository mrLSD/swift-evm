import ArgumentParser
import Foundation

struct VMCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "VM tests runner."
    )

    @Argument(help: "JSON file or directory for tests run.", completion: .file())
    var paths: [String]

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Verbose output.")
    var verbose: Bool = false

    @Flag(name: [.customShort("f"), .customLong("verbose_failed")], help: "Verbose failed-only output.")
    var verboseFailed: Bool = false

    @Flag(name: .customLong("enable-slow-tests"), help: "Include slow tests (mirrors the Rust `-F enable-slow-tests` cargo feature).")
    var enableSlowTests: Bool = false

    func run() throws {
        let verboseOutput = VerboseOutput(
            verbose: verbose,
            verboseFailed: verboseFailed,
            veryVerbose: false,
            printState: false,
            printSlow: false,
            dumpTransactions: nil
        )
        let decoder = JSONDecoder()
        var aggregate = TestExecutionResult.empty

        for root in paths {
            guard FileManager.default.fileExists(atPath: root) else {
                FileHandle.standardError.write(Data("data source does not exist: \(root)\n".utf8))
                throw ExitCode(2)
            }
            let files = FileWalker.enumerateJSON(at: root, enableSlowTests: enableSlowTests)
            for file in files {
                if verboseOutput.verbose {
                    print("RUN for: \(FileWalker.shortName(file))")
                }
                let url = URL(fileURLWithPath: file)
                let data: Data
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    FileHandle.standardError.write(Data("Failed to read \(file): \(error)\n".utf8))
                    throw ExitCode(2)
                }
                let suite: [String: VmTestCase]
                do {
                    suite = try decoder.decode([String: VmTestCase].self, from: data)
                } catch {
                    FileHandle.standardError.write(Data("Failed to parse \(file): \(error)\n".utf8))
                    throw ExitCode(2)
                }
                for (name, test) in suite {
                    let res = VMRunner.run(name: name, test: test, verbose: verboseOutput)
                    aggregate.merge(res)
                }
            }
        }

        printSummary(aggregate)
        if aggregate.failed > 0 { throw ExitCode(1) }
    }
}
