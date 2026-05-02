@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class ByteOrderSpec: QuickSpec {
    override class func spec() {
        describe("bytewiseLessThan") {
            context("base cases") {
                it("returns false for two empty arrays") {
                    expect(bytewiseLessThan([], [])).to(beFalse())
                }
                it("treats empty as less than any non-empty") {
                    expect(bytewiseLessThan([], [0x00])).to(beTrue())
                    expect(bytewiseLessThan([0x00], [])).to(beFalse())
                }
                it("returns false for equal arrays") {
                    expect(bytewiseLessThan([0x00, 0x01, 0xff], [0x00, 0x01, 0xff])).to(beFalse())
                }
            }

            context("prefix relations") {
                it("returns true when lhs is a strict prefix of rhs") {
                    expect(bytewiseLessThan([0xab, 0xcd], [0xab, 0xcd, 0xef])).to(beTrue())
                }
                it("returns false when rhs is a strict prefix of lhs") {
                    expect(bytewiseLessThan([0xab, 0xcd, 0xef], [0xab, 0xcd])).to(beFalse())
                }
            }

            context("differing-byte semantics") {
                it("uses only the first differing byte") {
                    expect(bytewiseLessThan([0x01, 0xff, 0xff], [0x02, 0x00, 0x00])).to(beTrue())
                    expect(bytewiseLessThan([0x02, 0x00, 0x00], [0x01, 0xff, 0xff])).to(beFalse())
                }
                it("compares bytes UNSIGNED — 0x80 > 0x7f, never the reverse") {
                    expect(bytewiseLessThan([0x80], [0x7f])).to(beFalse())
                    expect(bytewiseLessThan([0x7f], [0x80])).to(beTrue())
                    expect(bytewiseLessThan([0x00], [0xff])).to(beTrue())
                    expect(bytewiseLessThan([0xff], [0x00])).to(beFalse())
                }
            }

            context("strict-weak-ordering invariants") {
                it("is irreflexive on identical content") {
                    let buf: [UInt8] = (0..<32).map { UInt8($0) }
                    expect(bytewiseLessThan(buf, buf)).to(beFalse())
                }
                it("is asymmetric for unequal pairs") {
                    let a: [UInt8] = [0, 0, 1]
                    let b: [UInt8] = [0, 1, 0]
                    expect(bytewiseLessThan(a, b)).to(beTrue())
                    expect(bytewiseLessThan(b, a)).to(beFalse())
                }
                it("is transitive on a triple") {
                    let a: [UInt8] = [0x10]
                    let b: [UInt8] = [0x20]
                    let c: [UInt8] = [0x30]
                    expect(bytewiseLessThan(a, b)).to(beTrue())
                    expect(bytewiseLessThan(b, c)).to(beTrue())
                    expect(bytewiseLessThan(a, c)).to(beTrue())
                }
            }

            context("randomized cross-check") {
                it("agrees with the equivalent zip-based reference loop on 200 random pairs") {
                    func reference(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
                        for (l, r) in zip(lhs, rhs) {
                            if l != r { return l < r }
                        }
                        return lhs.count < rhs.count
                    }
                    var rng = SystemRandomNumberGenerator()
                    for _ in 0..<200 {
                        let lhs = (0..<Int.random(in: 0...64, using: &rng)).map { _ in UInt8.random(in: .min ... .max, using: &rng) }
                        let rhs = (0..<Int.random(in: 0...64, using: &rng)).map { _ in UInt8.random(in: .min ... .max, using: &rng) }
                        expect(bytewiseLessThan(lhs, rhs)).to(equal(reference(lhs, rhs)))
                    }
                }
            }
        }

        describe("Dictionary.keysSortedByBytes") {
            context("with H160 keys") {
                it("returns the keys ordered by big-endian bytes") {
                    let dict: [H160: Int] = [
                        h160LastByte(0x03): 0,
                        h160LastByte(0x01): 0,
                        h160LastByte(0x02): 0,
                        h160LastByte(0xff): 0,
                        h160LastByte(0x00): 0
                    ]
                    let sorted = dict.keysSortedByBytes()
                    expect(sorted.map { $0.BYTES.last! }).to(equal([0x00, 0x01, 0x02, 0x03, 0xff]))
                }
                it("is stable across repeated calls") {
                    let dict: [H160: Int] = [
                        h160LastByte(0xaa): 0,
                        h160LastByte(0x55): 0,
                        h160LastByte(0x01): 0
                    ]
                    let s1 = dict.keysSortedByBytes()
                    let s2 = dict.keysSortedByBytes()
                    expect(s1.map { $0.BYTES }).to(equal(s2.map { $0.BYTES }))
                }
                it("returns an empty array for an empty dict") {
                    let empty: [H160: Int] = [:]
                    expect(empty.keysSortedByBytes()).to(beEmpty())
                }
                it("agrees with the reference (zip-based) sort on 25 random keys") {
                    let dict: [H160: Int] = (0..<25).reduce(into: [:]) { acc, _ in
                        var bytes = [UInt8](repeating: 0, count: 20)
                        for i in 0..<20 { bytes[i] = UInt8.random(in: .min ... .max) }
                        acc[H160(from: bytes)] = 0
                    }
                    let fast = dict.keysSortedByBytes().map { $0.BYTES }
                    let reference = dict.keys.sorted { lhs, rhs in
                        for (l, r) in zip(lhs.BYTES, rhs.BYTES) { if l != r { return l < r } }
                        return lhs.BYTES.count < rhs.BYTES.count
                    }.map { $0.BYTES }
                    expect(fast).to(equal(reference))
                }
            }
            context("with H256 keys") {
                it("returns the keys ordered by big-endian bytes") {
                    let dict: [H256: Int] = [
                        h256LastByte(0x03): 0,
                        h256LastByte(0x01): 0,
                        h256LastByte(0x02): 0
                    ]
                    expect(dict.keysSortedByBytes().map { $0.BYTES.last! })
                        .to(equal([0x01, 0x02, 0x03]))
                }
            }
        }

        describe("Dictionary.pairsSortedByBytes") {
            it("returns (key, value) pairs sorted by key bytes — values intact") {
                let dict: [H160: String] = [
                    h160LastByte(0x03): "C",
                    h160LastByte(0x01): "A",
                    h160LastByte(0x02): "B"
                ]
                let pairs = dict.pairsSortedByBytes()
                expect(pairs.map { $0.1 }).to(equal(["A", "B", "C"]))
                expect(pairs.map { $0.0.BYTES.last! }).to(equal([0x01, 0x02, 0x03]))
            }
            it("preserves value identity across 16 random pairings") {
                let dict: [H160: Int] = (0..<16).reduce(into: [:]) { acc, i in
                    acc[h160LastByte(UInt8(i * 7))] = i * 100
                }
                let pairs = dict.pairsSortedByBytes()
                for (key, value) in pairs {
                    expect(dict[key]).to(equal(value))
                }
            }
            it("returns an empty array for an empty dict") {
                let empty: [H160: Int] = [:]
                expect(empty.pairsSortedByBytes().count).to(equal(0))
            }
        }
    }
}
