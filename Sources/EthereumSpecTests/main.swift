import ArgumentParser

// Coverage note: this file contains the executable entry point. It is exercised by every
// CLI invocation (smoke-tested via the Makefile + CI), but cannot be unit-covered since
// XCTest cannot enter the binary's `main`. The single-line body ensures the gap is minimal.
EthereumSpecTestsCommand.main()
