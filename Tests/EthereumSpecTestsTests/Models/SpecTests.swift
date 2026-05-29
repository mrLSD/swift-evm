@testable import EthereumSpecTests
import Foundation
import Interpreter
import Nimble
import Quick

final class SpecSpec: QuickSpec {
    override class func spec() {
        describe("Spec type") {
            let decoder = JSONDecoder()
            struct W: Decodable { let s: Spec }

            context("rawString parsing") {
                it("accepts every canonical fork name") {
                    let cases: [(String, Spec)] = [
                        ("Frontier", .Frontier),
                        ("Homestead", .Homestead),
                        ("EIP150", .Tangerine),
                        ("EIP158", .SpuriousDragon),
                        ("Byzantium", .Byzantium),
                        ("Constantinople", .Constantinople),
                        ("Petersburg", .Petersburg),
                        ("Istanbul", .Istanbul),
                        ("Berlin", .Berlin),
                        ("London", .London),
                        ("Paris", .Merge),
                        ("Merge", .Merge),
                        ("Shanghai", .Shanghai),
                        ("Cancun", .Cancun),
                        ("Prague", .Prague),
                        ("Osaka", .Osaka)
                    ]
                    for (raw, expected) in cases {
                        expect(Spec(rawString: raw)).to(equal(expected), description: raw)
                    }
                }
                it("accepts all historical aliases") {
                    let aliases: [(String, Spec)] = [
                        ("FrontierToHomesteadAt5", .Homestead),
                        ("HomesteadToDaoAt5", .Tangerine),
                        ("HomesteadToEIP150At5", .Tangerine),
                        ("EIP158ToByzantiumAt5", .Byzantium),
                        ("ConstantinopleFix", .Constantinople),
                        ("ByzantiumToConstantinopleAt5", .Constantinople),
                        ("ByzantiumToConstantinopleFixAt5", .Constantinople),
                        ("BerlinToLondonAt5", .London)
                    ]
                    for (raw, expected) in aliases {
                        expect(Spec(rawString: raw)).to(equal(expected), description: raw)
                    }
                }
                it("returns nil for unknown names") {
                    expect(Spec(rawString: "NotAFork")).to(beNil())
                    expect(Spec(rawString: "")).to(beNil())
                }
            }

            context("canonicalName") {
                it("maps every case to its variant name") {
                    let expected: [Spec: String] = [
                        .Frontier: "Frontier",
                        .Homestead: "Homestead",
                        .Tangerine: "Tangerine",
                        .SpuriousDragon: "SpuriousDragon",
                        .Byzantium: "Byzantium",
                        .Constantinople: "Constantinople",
                        .Petersburg: "Petersburg",
                        .Istanbul: "Istanbul",
                        .Berlin: "Berlin",
                        .London: "London",
                        .Merge: "Merge",
                        .Shanghai: "Shanghai",
                        .Cancun: "Cancun",
                        .Prague: "Prague",
                        .Osaka: "Osaka"
                    ]
                    expect(Spec.allCases.count).to(equal(expected.count))
                    for (spec, name) in expected {
                        expect(spec.canonicalName).to(equal(name))
                    }
                }
            }

            context("Comparable ordering") {
                it("orders forks chronologically by rawValue") {
                    expect(Spec.Frontier < Spec.Berlin).to(beTrue())
                    expect(Spec.Cancun < Spec.Prague).to(beTrue())
                    expect(Spec.Merge < Spec.Shanghai).to(beTrue())
                    expect(Spec.Berlin < Spec.London).to(beTrue())
                }
                it("is irreflexive") {
                    expect(Spec.Cancun < Spec.Cancun).to(beFalse())
                }
            }

            context("toHardFork") {
                it("collapses Petersburg to Constantinople") {
                    expect(Spec.Petersburg.toHardFork()).to(equal(HardFork.Constantinople))
                }
                it("maps Merge to Paris") {
                    expect(Spec.Merge.toHardFork()).to(equal(HardFork.Paris))
                }
                it("preserves other forks identically") {
                    let cases: [(Spec, HardFork)] = [
                        (.Frontier, .Frontier),
                        (.Homestead, .Homestead),
                        (.Tangerine, .Tangerine),
                        (.SpuriousDragon, .SpuriousDragon),
                        (.Byzantium, .Byzantium),
                        (.Constantinople, .Constantinople),
                        (.Istanbul, .Istanbul),
                        (.Berlin, .Berlin),
                        (.London, .London),
                        (.Shanghai, .Shanghai),
                        (.Cancun, .Cancun),
                        (.Prague, .Prague),
                        (.Osaka, .Osaka)
                    ]
                    for (spec, hf) in cases {
                        expect(spec.toHardFork()).to(equal(hf), description: spec.canonicalName)
                    }
                }
            }

            context("hasExecutableConfig") {
                it("flags pre-Istanbul forks as not executable") {
                    let preIstanbul: [Spec] = [.Frontier, .Homestead, .Tangerine, .SpuriousDragon,
                                               .Byzantium, .Constantinople, .Petersburg]
                    for s in preIstanbul {
                        expect(s.hasExecutableConfig).to(beFalse(), description: s.canonicalName)
                    }
                }
                it("flags Istanbul-and-later forks as executable") {
                    let executable: [Spec] = [.Istanbul, .Berlin, .London, .Merge,
                                              .Shanghai, .Cancun, .Prague, .Osaka]
                    for s in executable {
                        expect(s.hasExecutableConfig).to(beTrue(), description: s.canonicalName)
                    }
                }
            }

            context("Decodable") {
                it("decodes a known canonical name") {
                    let json = #"{"s":"Cancun"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).s).to(equal(Spec.Cancun))
                }
                it("decodes a historical alias") {
                    let json = #"{"s":"BerlinToLondonAt5"}"#.data(using: .utf8)!
                    expect(try! decoder.decode(W.self, from: json).s).to(equal(Spec.London))
                }
                it("rejects an unknown name") {
                    let json = #"{"s":"NotAFork"}"#.data(using: .utf8)!
                    expect { try decoder.decode(W.self, from: json) }
                        .to(throwError { (e: Error) in
                            expect(String(describing: e)).to(contain("Unknown Spec"))
                        })
                }
            }
        }
    }
}
