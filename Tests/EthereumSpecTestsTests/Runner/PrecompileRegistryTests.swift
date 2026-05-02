@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class PrecompileRegistrySpec: QuickSpec {
    override class func spec() {
        describe("PrecompileRegistry type") {
            context("lookup") {
                it("returns nil for every standard precompile address on every spec (current stub)") {
                    let addrs: [UInt8] = [
                        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
                        0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11
                    ]
                    let specs: [Spec] = [.Frontier, .Berlin, .Cancun, .Prague, .Osaka]
                    for spec in specs {
                        for byte in addrs {
                            let addr = h160LastByte(byte)
                            expect(PrecompileRegistry.lookup(address: addr, spec: spec)).to(beNil(),
                                description: "lookup(\(byte), \(spec)) should be nil while stub is in place")
                        }
                    }
                }
                it("returns nil for the zero address too") {
                    expect(PrecompileRegistry.lookup(address: H160.ZERO, spec: .Cancun)).to(beNil())
                }
            }

            context("Outcome") {
                it("supports a success variant carrying return data + gas") {
                    let outcome = PrecompileRegistry.Outcome.success(returnData: [0xab], gasUsed: 10)
                    if case .success(let data, let gas) = outcome {
                        expect(data).to(equal([0xab]))
                        expect(gas).to(equal(10))
                    } else {
                        fail("expected .success")
                    }
                }
                it("supports a failure variant carrying a reason string") {
                    let outcome = PrecompileRegistry.Outcome.failure(reason: "oops")
                    if case .failure(let r) = outcome {
                        expect(r).to(equal("oops"))
                    } else {
                        fail("expected .failure")
                    }
                }
            }
        }
    }
}
