import ArgumentParser
import Foundation

struct StateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "state",
        abstract: "State tests runner."
    )

    @Argument(help: "JSON file or directory for tests run.", completion: .file())
    var paths: [String]

    @Option(name: [.customShort("n"), .customLong("test-name")], help: #"Filter for the test name (e.g. "test/name")."#)
    var testName: String?

    @Option(name: [.customShort("s"), .customLong("spec")], help: "Ethereum hard fork (e.g. London, Cancun, Prague).")
    var spec: String?

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Verbose output.")
    var verbose: Bool = false

    @Flag(name: [.customShort("f"), .customLong("verbose_failed")], help: "Verbose failed-only output.")
    var verboseFailed: Bool = false

    @Flag(name: [.customShort("w"), .customLong("very_verbose")], help: "Very verbose output.")
    var veryVerbose: Bool = false

    @Flag(name: [.customShort("p"), .customLong("print_state")], help: "Print state when the test fails.")
    var printState: Bool = false

    @Option(name: .customLong("dump_successful_tx"), help: "Optional file to dump all successful transactions to.", completion: .file())
    var dumpSuccessfulTx: String?

    @Flag(name: .customLong("slow_tests"), help: "Print state slow tests.")
    var slowTests: Bool = false

    @Flag(name: .customLong("enable-slow-tests"), help: "Include slow tests (mirrors the Rust `-F enable-slow-tests` cargo feature).")
    var enableSlowTests: Bool = false

    func run() throws {
        let dumpURL = dumpSuccessfulTx.map { URL(fileURLWithPath: $0) }
        let verboseOutput = VerboseOutput(
            verbose: verbose,
            verboseFailed: verboseFailed,
            veryVerbose: veryVerbose,
            printState: printState,
            printSlow: slowTests,
            dumpTransactions: dumpURL
        )

        var specFilter: Spec? = nil
        if let raw = spec {
            guard let parsed = Spec(rawString: raw) else {
                FileHandle.standardError.write(Data("Unknown --spec value: '\(raw)'\n".utf8))
                throw ExitCode(2)
            }
            specFilter = parsed
        }

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
                let suite: [String: StateTestCase]
                do {
                    suite = try decoder.decode([String: StateTestCase].self, from: data)
                } catch {
                    FileHandle.standardError.write(Data("Failed to parse \(file): \(error)\n".utf8))
                    throw ExitCode(2)
                }
                for (name, test) in suite {
                    if let filter = testName, !name.contains(filter) { continue }
                    let res = StateRunner.run(name: name, test: test, specFilter: specFilter, verbose: verboseOutput)
                    aggregate.merge(res)
                }
            }
        }

        printSummary(aggregate)

        if verboseOutput.printSlow {
            printSlowTests(aggregate.slowTests)
        }

        if let dumpURL = verboseOutput.dumpTransactions {
            do {
                try writeDumpedTransactions(aggregate.dumpedTransactions, to: dumpURL)
            } catch {
                FileHandle.standardError.write(Data("Failed to write dump file \(dumpURL.path): \(error)\n".utf8))
                throw ExitCode(2)
            }
        }

        if aggregate.failed > 0 { throw ExitCode(1) }
    }
}
