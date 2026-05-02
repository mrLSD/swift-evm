import ArgumentParser

struct EthereumSpecTestsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "EthereumSpecTests",
        abstract: "Ethereum spec tests runner for the Swift EVM (port of aurora-evm/evm-tests).",
        version: "0.1.0",
        subcommands: [VMCommand.self, StateCommand.self]
    )
}
