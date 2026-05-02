@testable import EthereumSpecTests
import Foundation
import Nimble
import Quick

final class InfoSpec: QuickSpec {
    override class func spec() {
        describe("Info type") {
            let decoder = JSONDecoder()

            it("decodes all known fields, including hyphenated keys") {
                let json = #"""
                {
                  "comment": "hello",
                  "filling-rpc-server": "rpc",
                  "filling-tool-version": "v1",
                  "fixture-format": "fmt-a",
                  "generatedTestHash": "abcd",
                  "lllcversion": "0.5",
                  "solidity": "0.8.0",
                  "source": "src",
                  "sourceHash": "hash",
                  "labels": { "x": "1", "y": "2" },
                  "filling-transition-tool": "tool",
                  "hash": "h",
                  "description": "d",
                  "url": "u",
                  "reference-spec": "rs",
                  "reference-spec-version": "rsv"
                }
                """#.data(using: .utf8)!
                let info = try! decoder.decode(Info.self, from: json)
                expect(info.comment).to(equal("hello"))
                expect(info.fillingRpcServer).to(equal("rpc"))
                expect(info.fillingToolVersion).to(equal("v1"))
                expect(info.fixtureFormat).to(equal("fmt-a"))
                expect(info.generatedTestHash).to(equal("abcd"))
                expect(info.lllcversion).to(equal("0.5"))
                expect(info.solidity).to(equal("0.8.0"))
                expect(info.source).to(equal("src"))
                expect(info.sourceHash).to(equal("hash"))
                expect(info.labels?.count).to(equal(2))
                expect(info.fillingTransitionTool).to(equal("tool"))
                expect(info.hash).to(equal("h"))
                expect(info.description).to(equal("d"))
                expect(info.url).to(equal("u"))
                expect(info.referenceSpec).to(equal("rs"))
                expect(info.referenceSpecVersion).to(equal("rsv"))
            }
            it("falls back to the alternate `fixture_format` key when `fixture-format` is absent") {
                let json = #"""
                { "fixture_format": "alt-fmt" }
                """#.data(using: .utf8)!
                let info = try! decoder.decode(Info.self, from: json)
                expect(info.fixtureFormat).to(equal("alt-fmt"))
            }
            it("decodes an empty object") {
                let json = "{}".data(using: .utf8)!
                let info = try! decoder.decode(Info.self, from: json)
                expect(info.comment).to(beNil())
                expect(info.labels).to(beNil())
            }
        }
    }
}
