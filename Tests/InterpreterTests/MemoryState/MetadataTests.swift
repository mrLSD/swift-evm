@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class MemoryStateMetadataSpec: QuickSpec {
    override class func spec() {
        describe("MemoryState.Metadata") {
            let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
            let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))
            let key1 = H256(from: [UInt8](repeating: 0xaa, count: 32))
            let storage1 = MemoryState.Storage(address: addr1, index: key1)

            context("Initialization") {
                it("initializes with Berlin hardfork (accessed data enabled)") {
                    let gas = Gas(limit: 1000)
                    let metadata = MemoryState.Metadata(gasometer: gas, hardFork: .Berlin)

                    expect(metadata.accessedData()).toNot(beNil())
                    expect(metadata.isStatic).to(beFalse())
                    expect(metadata.depth).to(beNil())
                }

                it("initializes with Frontier hardfork (accessed data disabled)") {
                    let gas = Gas(limit: 1000)
                    let metadata = MemoryState.Metadata(gasometer: gas, hardFork: .Frontier)

                    expect(metadata.accessedData()).to(beNil())
                }
            }

            context("spitChild (Nested Calls)") {
                it("increments depth correctly") {
                    let gas = Gas(limit: 5000)
                    let parent = MemoryState.Metadata(gasometer: gas, hardFork: .Berlin)
                    let child = parent.spitChild(gasLimit: 1000, isStatic: false)
                    expect(child.depth).to(equal(0))

                    let grandchild = child.spitChild(gasLimit: 500, isStatic: false)
                    expect(grandchild.depth).to(equal(1))
                }

                it("propagates isStatic flag (sticky)") {
                    let parentStatic = MemoryState.Metadata(gasometer: Gas(limit: 1000), isStatic: true, depth: 1, accessed: nil)
                    let child = parentStatic.spitChild(gasLimit: 500, isStatic: false)

                    expect(child.isStatic).to(beTrue()) // true || false = true
                }

                it("resets accessed data for child but preserves the structure existence") {
                    let gas = Gas(limit: 5000)
                    var parent = MemoryState.Metadata(gasometer: gas, hardFork: .Berlin)
                    parent.accessAddress(addr1)
                    let child = parent.spitChild(gasLimit: 1000, isStatic: false)

                    expect(child.accessedData()).toNot(beNil())
                    expect(child.accessedData()?.addresses).to(beEmpty())
                }
            }

            context("Swallow (Merging Results)") {
                it("swallowCommit merges gas, refunds and accessed data") {
                    var parentGas = Gas(limit: 5000)
                    _ = parentGas.recordCost(cost: 1000) // 4000 left
                    var parent = MemoryState.Metadata(gasometer: parentGas, isStatic: false, depth: 0, accessed: MemoryState.Accessed())

                    var childGas = Gas(limit: 1000)
                    _ = childGas.recordCost(cost: 200) // 800 left
                    childGas.recordRefund(refund: 100)
                    var child = MemoryState.Metadata(gasometer: childGas, isStatic: false, depth: 1, accessed: MemoryState.Accessed())
                    child.accessAddress(addr1)

                    parent.swallowCommit(from: child)

                    // Gas: parent_remaining (4000) + child_remaining (800) = 4800
                    expect(parent.gasometer.remaining).to(equal(4800))
                    expect(parent.gasometer.refunded).to(equal(100))
                    expect(parent.accessedData()?.addresses).to(contain(addr1))
                }

                it("swallowRevert only merges gas stipend") {
                    var parentGas = Gas(limit: 2000)
                    _ = parentGas.recordCost(cost: 500) // 1500 left
                    var parent = MemoryState.Metadata(gasometer: parentGas, isStatic: false, depth: 0, accessed: MemoryState.Accessed())

                    let childGas = Gas(limit: 500) // 500 left (no cost)
                    let child = MemoryState.Metadata(gasometer: childGas, isStatic: false, depth: 1, accessed: MemoryState.Accessed())

                    parent.swallowRevert(from: child)

                    expect(parent.gasometer.remaining).to(equal(2000)) // 1500 + 500
                    expect(parent.accessedData()?.addresses).to(beEmpty()) // Access list NOT merged
                }
            }

            context("calcGasLimitAndRecord") {
                it("reserves the smaller of the target and the remaining gas and charges it") {
                    let cases: [(remaining: UInt64, targetGas: UInt64, reserved: UInt64, left: UInt64)] = [
                        (0, 0, 0, 0),
                        (0, 1, 0, 0),
                        (100, 0, 0, 100),
                        (100, 40, 40, 60),
                        (100, 100, 100, 0),
                        (100, 101, 100, 0),
                        (UInt64.max, UInt64.max, UInt64.max, 0),
                        (79_000, 100_000, 79_000, 0),
                    ]
                    for c in cases {
                        var metadata = MemoryState.Metadata(gasometer: Gas(limit: c.remaining), hardFork: .Berlin)
                        let reserved = metadata.calcGasLimitAndRecord(targetGas: c.targetGas)
                        let detail = "remaining \(c.remaining), target \(c.targetGas)"

                        expect(reserved).to(equal(c.reserved), description: detail)
                        expect(metadata.gasometer.remaining).to(equal(c.left), description: detail)
                    }
                }

                it("reserves each call from what the previous one left") {
                    var metadata = MemoryState.Metadata(gasometer: Gas(limit: 100), hardFork: .Berlin)

                    let first = metadata.calcGasLimitAndRecord(targetGas: 30)
                    expect(first).to(equal(30))
                    expect(metadata.gasometer.remaining).to(equal(70))

                    let second = metadata.calcGasLimitAndRecord(targetGas: 90)
                    expect(second).to(equal(70))
                    expect(metadata.gasometer.remaining).to(equal(0))
                }

                it("changes nothing but the remaining gas") {
                    for refund: Int64 in [50, -50] {
                        var gas = Gas(limit: 1000)
                        _ = gas.recordCost(cost: 400)
                        _ = gas.memoryGas.resize(end: 0, length: 64)
                        gas.recordRefund(refund: refund)
                        var accessed = MemoryState.Accessed()
                        accessed.setAccessAddress(addr1)
                        var metadata = MemoryState.Metadata(gasometer: gas, isStatic: true, depth: 3, accessed: accessed)
                        let before = metadata

                        let reserved = metadata.calcGasLimitAndRecord(targetGas: 100)
                        expect(reserved).to(equal(100))
                        expect(metadata.gasometer.remaining).to(equal(500))
                        expect(metadata.gasometer.limit).to(equal(1000))
                        expect(metadata.gasometer.refunded).to(equal(refund))
                        expect(metadata.gasometer.memoryGas.gasCost).to(equal(6))
                        expect(metadata.gasometer.memoryGas).to(equal(before.gasometer.memoryGas))
                        expect(metadata.isStatic).to(beTrue())
                        expect(metadata.depth).to(equal(3))
                        expect(metadata.accessedData()).to(equal(before.accessedData()))
                        expect(metadata.accessedData()?.addresses).to(contain(addr1))
                    }
                }

                it("does not depend on the hard fork or on the presence of the access journal") {
                    for fork in HardFork.allCases {
                        var metadata = MemoryState.Metadata(gasometer: Gas(limit: 100), hardFork: fork)
                        let before = metadata

                        let reserved = metadata.calcGasLimitAndRecord(targetGas: 40)
                        expect(reserved).to(equal(40), description: "fork \(fork)")
                        expect(metadata.gasometer.remaining).to(equal(60), description: "fork \(fork)")
                        if let journal = before.accessedData() {
                            expect(metadata.accessedData()).to(equal(journal), description: "fork \(fork)")
                        } else {
                            expect(metadata.accessedData()).to(beNil(), description: "fork \(fork)")
                        }
                    }
                }
            }

            context("Access dataw Management") {
                it("manages authority (EIP-7702)") {
                    var metadata = MemoryState.Metadata(gasometer: Gas(limit: 1000), hardFork: .Berlin)
                    metadata.addAuthority(authority: addr1, address: addr2)

                    expect(metadata.accessedData()?.isAuthority(addr1)).to(beTrue())
                    expect(metadata.accessedData()?.getAuthorityTarget(addr1)).to(equal(addr2))

                    metadata.removeAuthority(addr1)
                    expect(metadata.accessedData()?.isAuthority(addr1)).to(beFalse())
                }

                it("records storage access") {
                    var metadata = MemoryState.Metadata(gasometer: Gas(limit: 1000), hardFork: .Berlin)
                    metadata.accessStorage(address: addr1, key: key1)

                    expect(metadata.accessedData()?.storage).to(contain(storage1))
                }

                it("records multiple addresses via iterator") {
                    var metadata = MemoryState.Metadata(gasometer: Gas(limit: 1000), hardFork: .Berlin)
                    var iterator = [addr1, addr2].makeIterator()
                    metadata.accessAddresses(&iterator)

                    expect(metadata.accessedData()?.addresses).to(contain([addr1, addr2]))
                }
            }

            context("Additional coverage for accessStorages and swallowCommit") {
                let key2 = H256(from: [UInt8](repeating: 0xbb, count: 32))
                let storage2 = MemoryState.Storage(address: addr2, index: key2)

                it("records multiple storage slots via iterator using accessStorages") {
                    var metadata = MemoryState.Metadata(gasometer: Gas(limit: 1000), hardFork: .Berlin)
                    var iterator = [storage1, storage2].makeIterator()

                    metadata.accessStorages(&iterator)

                    let accessed = metadata.accessedData()
                    expect(accessed?.storage).to(contain([storage1, storage2]))
                    expect(accessed?.storage.count).to(equal(2))
                }

                it("swallowCommit: branch where parent accessed is nil but child is present") {
                    var parent = MemoryState.Metadata(
                        gasometer: Gas(limit: 5000),
                        isStatic: false,
                        depth: nil,
                        accessed: nil
                    )

                    var childAccessed = MemoryState.Accessed()
                    childAccessed.setAccessAddress(addr1)
                    let child = MemoryState.Metadata(
                        gasometer: Gas(limit: 1000),
                        isStatic: false,
                        depth: 0,
                        accessed: childAccessed
                    )

                    parent.swallowCommit(from: child)

                    expect(parent.accessedData()).toNot(beNil())
                    expect(parent.accessedData()?.addresses).to(contain(addr1))
                }

                it("swallowCommit: branch where both parent and child accessed are present") {
                    var parent = MemoryState.Metadata(gasometer: Gas(limit: 5000), hardFork: .Berlin)
                    parent.accessAddress(addr1)

                    var child = MemoryState.Metadata(gasometer: Gas(limit: 1000), hardFork: .Berlin)
                    child.accessAddress(addr2)

                    parent.swallowCommit(from: child)

                    expect(parent.accessedData()?.addresses).to(contain([addr1, addr2]))
                }
            }
        }
    }
}
