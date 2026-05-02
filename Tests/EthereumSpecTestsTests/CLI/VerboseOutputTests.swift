@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class VerboseOutputSpec: QuickSpec {
    override class func spec() {
        describe("VerboseOutput type") {
            it("stores all flags and the dump URL verbatim") {
                let url = URL(fileURLWithPath: "/tmp/dump.json")
                let v = VerboseOutput(
                    verbose: true, verboseFailed: true, veryVerbose: true,
                    printState: true, printSlow: true, dumpTransactions: url
                )
                expect(v.verbose).to(beTrue())
                expect(v.verboseFailed).to(beTrue())
                expect(v.veryVerbose).to(beTrue())
                expect(v.printState).to(beTrue())
                expect(v.printSlow).to(beTrue())
                expect(v.dumpTransactions).to(equal(url))
            }
            it("defaults all-false / nil are stored verbatim") {
                let v = VerboseOutput(verbose: false, verboseFailed: false, veryVerbose: false,
                                      printState: false, printSlow: false, dumpTransactions: nil)
                expect(v.verbose).to(beFalse())
                expect(v.dumpTransactions).to(beNil())
            }
        }
    }
}
