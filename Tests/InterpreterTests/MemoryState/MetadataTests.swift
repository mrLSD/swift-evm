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

            context("Access List Management") {
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
