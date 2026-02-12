
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class AccessedSpec: QuickSpec {
    override class func spec() {
        // Тестовые данные
        let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
        let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))
        let addr3 = H160(from: [UInt8](repeating: 0x03, count: 20))

        let index1 = H256(from: [UInt8](repeating: 0xaa, count: 32))
        let index2 = H256(from: [UInt8](repeating: 0xbb, count: 32))

        let storage1 = MemoryState.Storage(address: addr1, index: index1)
        let storage2 = MemoryState.Storage(address: addr2, index: index2)

        describe("Accessed struct") {
            context("initialization") {
                it("should initialize with empty data") {
                    let accessed = MemoryState.Accessed()
                    expect(accessed.addresses).to(beEmpty())
                    expect(accessed.storage).to(beEmpty())
                    expect(accessed.authority).to(beEmpty())
                }

                it("should initialize with predefined data") {
                    let accessed = MemoryState.Accessed(
                        accessedAddresses: [addr1],
                        accessedStorage: [storage1],
                        authority: [addr1: addr2]
                    )
                    expect(accessed.addresses).to(contain(addr1))
                    expect(accessed.storage).to(contain(storage1))
                    expect(accessed.authority[addr1]).to(equal(addr2))
                }
            }

            context("address access") {
                it("should add a single address via setAccessAddress") {
                    var accessed = MemoryState.Accessed()
                    accessed.setAccessAddress(addr1)

                    expect(accessed.addresses).to(contain(addr1))
                    expect(accessed.addresses.count).to(equal(1))
                }

                it("should add multiple addresses via Sequence") {
                    var accessed = MemoryState.Accessed()
                    accessed.accessAddresses([addr1, addr2, addr1])

                    expect(accessed.addresses).to(contain([addr1, addr2]))
                    expect(accessed.addresses.count).to(equal(2))
                }

                it("should add multiple addresses via Iterator") {
                    var accessed = MemoryState.Accessed()
                    var iterator = [addr2, addr3].makeIterator()
                    accessed.accessAddresses(&iterator)

                    expect(accessed.addresses).to(contain([addr2, addr3]))
                    expect(accessed.addresses.count).to(equal(2))
                }
            }

            context("storage access") {
                it("should add storages via Iterator") {
                    var accessed = MemoryState.Accessed()
                    var iterator = [storage1, storage2].makeIterator()
                    accessed.addStorages(&iterator)

                    expect(accessed.storage).to(contain([storage1, storage2]))
                    expect(accessed.storage.count).to(equal(2))
                }
            }

            context("authority list (EIP-7702)") {
                it("should add and retrieve authority targets") {
                    var accessed = MemoryState.Accessed()
                    accessed.addAuthority(authority: addr1, address: addr2)

                    expect(accessed.isAuthority(addr1)).to(beTrue())
                    expect(accessed.isAuthority(addr2)).to(beFalse())
                    expect(accessed.getAuthorityTarget(addr1)).to(equal(addr2))
                }

                it("should remove authority from the list") {
                    var accessed = MemoryState.Accessed()
                    accessed.addAuthority(authority: addr1, address: addr2)

                    expect(accessed.isAuthority(addr1)).to(beTrue())

                    accessed.removeAuthority(addr1)
                    expect(accessed.isAuthority(addr1)).to(beFalse())
                    expect(accessed.getAuthorityTarget(addr1)).to(beNil())
                }
            }

            context("merging") {
                it("should correctly merge two Accessed instances") {
                    var base = MemoryState.Accessed(
                        accessedAddresses: [addr1],
                        accessedStorage: [storage1],
                        authority: [addr1: addr1]
                    )

                    let other = MemoryState.Accessed(
                        accessedAddresses: [addr2],
                        accessedStorage: [storage2],
                        authority: [addr1: addr2, addr3: addr3]
                    )

                    base.merge(with: other)

                    expect(base.addresses).to(contain([addr1, addr2]))
                    expect(base.storage).to(contain([storage1, storage2]))
                    expect(base.authority.count).to(equal(2))
                    expect(base.getAuthorityTarget(addr1)).to(equal(addr2))
                    expect(base.getAuthorityTarget(addr3)).to(equal(addr3))
                }
            }
        }
    }
}
