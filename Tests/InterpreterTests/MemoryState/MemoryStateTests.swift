@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

// MARK: - Mock Backend

final class MockBackend: Backend {
    var accounts: [H160: BasicAccount] = [:]
    var codes: [H160: [UInt8]] = [:]
    var storages: [H160: [H256: H256]] = [:]

    let sender = H160(from: [UInt8](repeating: 0x0a, count: 20))
    let address1 = H160(from: [UInt8](repeating: 0x01, count: 20))
    let coinBase = H160(from: [UInt8](repeating: 0x0b, count: 20))
    let storageKey1 = H256(from: U256(from: 10).toBigEndian)

    func gasPrice() -> U256 {
        U256(from: 333)
    }

    func origin() -> H160 {
        sender
    }

    func blockHash(number: U256) -> H256 {
        H256(from: U256(from: 100).toBigEndian)
    }

    func blockNumber() -> U256 {
        U256(from: 1000)
    }

    func blockCoinbase() -> H160 {
        coinBase
    }

    func blockTimestamp() -> U256 {
        U256(from: 1234567890)
    }

    func blockDifficulty() -> U256 {
        U256(from: 999)
    }

    func blockRandomness() -> H256? {
        H256(from: U256(from: 22).toBigEndian)
    }

    func blockGasLimit() -> U256 {
        U256(from: 8000000)
    }

    func blockBaseFeePerGas() -> U256 {
        U256(from: 300)
    }

    func chainId() -> U256 {
        U256(from: 1)
    }

    func blobGasPrice() -> U128 {
        U128(from: 410)
    }

    func getBlobHash(index: UInt) -> U256? {
        U256(from: 601)
    }

    func exists(address: H160) -> Bool {
        accounts[address] != nil
    }

    func basic(address: H160) -> BasicAccount {
        if address == sender {
            return BasicAccount(balance: U256(from: 3003), nonce: U256(from: 10))
        }
        return accounts[address] ?? BasicAccount.default
    }

    func code(address: H160) -> [UInt8] {
        if address == sender {
            return [10, 20, 30]
        }
        return codes[address] ?? []
    }

    func storage(address: H160, index: H256) -> H256 {
        if address == sender, index == storageKey1 {
            return H256(from: U256(from: 555).toBigEndian)
        }
        return storages[address]?[index] ?? H256.ZERO
    }

    func isEmptyStorage(address: H160) -> Bool {
        storages[address]?.isEmpty ?? true
    }

    func originalStorage(address: H160, index: H256) -> H256? {
        storages[address]?[index]
    }
}

// MARK: - Tests

final class MemoryStateSpec: QuickSpec {
    override class func spec() {
        describe("MemoryState") {
            context("Account lookups and Caching") {
                it("should fetch account from backend and cache it locally for balance and nonce") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    // First call - triggers getAccountAndTouch
                    let acc = state.getAccountAndTouch(backend.address1)
                    expect(acc.basic.balance).to(equal(U256.ZERO))

                    // Modify locally. It's only for testing that local state is separate from backend.
                    state.accounts[backend.address1]?.basic = BasicAccount(balance: U256(from: 2000), nonce: U256(from: 5))

                    // Verify local state changed but backend remains same
                    expect(state.basic(address: backend.address1).balance).to(equal(U256(from: 2000)))
                    expect(backend.basic(address: backend.address1).balance).to(equal(U256.ZERO))
                    expect(state.basic(address: backend.address1).nonce).to(equal(U256(from: 5)))
                    expect(backend.basic(address: backend.address1).nonce).to(equal(U256.ZERO))
                }

                it("should lookup account recursively in parent states") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    parentState.accounts[backend.address1] = StateAccount(basic: BasicAccount(balance: U256(from: 500), nonce: U256(from: 10)), code: [10, 20], reset: true)

                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    let knownAcc = childState.knownAccount(backend.address1)
                    expect(knownAcc).toNot(beNil())
                    expect(knownAcc?.basic.balance).to(equal(U256(from: 500)))
                    expect(knownAcc?.basic.nonce).to(equal(U256(from: 10)))
                    expect(knownAcc?.code).to(equal([10, 20]))
                    expect(knownAcc?.reset).to(equal(true))

                    expect(childState.knownAccount(backend.address1)?.basic.balance).to(equal(U256(from: 500)))
                    expect(childState.knownAccount(backend.address1)?.basic.nonce).to(equal(U256(from: 10)))
                }
            }

            context("Account state Balance and Nonce Mutations") {
                it("Deposit and withdraw for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    let acc = state.getAccountAndTouch(backend.sender)
                    expect(acc.basic.balance).to(equal(U256(from: 3003)))

                    state.deposit(address: backend.sender, value: U256(from: 1000))
                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))

                    let res = state.withdraw(address: backend.sender, value: U256(from: 2003))
                    expect(res).to(beSuccess())

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 2000)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Deposit and withdraw for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    parentState.deposit(address: backend.sender, value: U256(from: 1000))
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))

                    childState.deposit(address: backend.sender, value: U256(from: 1700))
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 5703)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))

                    let res1 = parentState.withdraw(address: backend.sender, value: U256(from: 2003))
                    expect(res1).to(beSuccess())
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 2000)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 5703)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))

                    let res2 = childState.withdraw(address: backend.sender, value: U256(from: 1323))
                    expect(res2).to(beSuccess())
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 2000)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 4380)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Deposit and Reset balance for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    let acc = state.getAccountAndTouch(backend.sender)
                    expect(acc.basic.balance).to(equal(U256(from: 3003)))

                    state.deposit(address: backend.sender, value: U256(from: 1000))
                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))

                    state.resetBalance(address: backend.sender)
                    expect(state.basic(address: backend.sender).balance).to(equal(U256.ZERO))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                }

                it("Deposit and Reset balance for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    parentState.deposit(address: backend.sender, value: U256(from: 1000))
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))

                    childState.deposit(address: backend.sender, value: U256(from: 1700))
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 4003)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 5703)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))

                    parentState.resetBalance(address: backend.sender)
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256.ZERO))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 5703)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))

                    childState.resetBalance(address: backend.sender)
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256.ZERO))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256.ZERO))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                }

                it("withdraw with OutOfFunds") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    let acc = state.getAccountAndTouch(backend.sender)
                    expect(acc.basic.balance).to(equal(U256(from: 3003)))

                    let res = state.withdraw(address: backend.sender, value: U256(from: 3004))
                    expect(res).to(beFailure { error in expect(error).to(equal(.OutOfFund)) })

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Increment nonce for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    let acc = state.getAccountAndTouch(backend.sender)
                    expect(acc.basic.nonce).to(equal(U256(from: 10)))

                    let res = state.incNonce(address: backend.sender)
                    expect(res).to(beSuccess())

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.sender).nonce).to(equal(U256(from: 11)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Increment nonce for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    let res1 = parentState.incNonce(address: backend.sender)
                    expect(res1).to(beSuccess())
                    expect(parentState.basic(address: backend.sender).nonce).to(equal(U256(from: 11)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 11)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))

                    let res2 = childState.incNonce(address: backend.sender)
                    expect(res2).to(beSuccess())
                    expect(parentState.basic(address: backend.sender).nonce).to(equal(U256(from: 11)))
                    expect(childState.basic(address: backend.sender).nonce).to(equal(U256(from: 12)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Increment nonce with overflow for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    let acc = state.getAccountAndTouch(backend.sender)
                    expect(acc.basic.nonce).to(equal(U256(from: 10)))

                    // Force nonce to max value to test overflow
                    state.accounts[backend.sender]?.basic.nonce = U256(from: UInt64.max)

                    let res = state.incNonce(address: backend.sender)
                    expect(res).to(beFailure { error in expect(error).to(equal(.MaxNonce)) })

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(backend.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.sender).nonce).to(equal(U256(from: UInt64.max)))
                    expect(backend.basic(address: backend.sender).nonce).to(equal(U256(from: 10)))
                }

                it("Account code for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: MockBackend(), hardFork: .Berlin)

                    expect(state.code(address: backend.sender)).to(equal([10, 20, 30]))
                    expect(backend.code(address: backend.sender)).to(equal([10, 20, 30]))

                    expect(state.knownAccount(backend.address1)?.code).to(beNil())
                    expect(state.code(address: backend.address1)).to(equal([]))
                    // After call `backend.code`, the knownAccount for address1 should be updated with empty code, so it should not be nil anymore.
                    expect(state.knownAccount(backend.address1)?.code).to(equal([]))
                    expect(backend.code(address: backend.address1)).to(equal([]))

                    state.setCode(address: backend.sender, code: [8, 5, 3])
                    state.setCode(address: backend.address1, code: [3, 5, 8])

                    expect(state.code(address: backend.sender)).to(equal([8, 5, 3]))
                    expect(backend.code(address: backend.sender)).to(equal([10, 20, 30]))
                    expect(state.code(address: backend.address1)).to(equal([3, 5, 8]))
                    expect(backend.code(address: backend.address1)).to(equal([]))
                }
            }

            context("Account state gat basic and touch") {
                it("Get basic for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    expect(parentState.knownAccount(backend.sender)).to(beNil())
                    expect(childState.knownAccount(backend.sender)).to(beNil())

                    // Account cashed in parent state after getAccountAndTouch call
                    expect(parentState.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    // Already cached in parent state
                    expect(childState.knownAccount(backend.sender)?.basic.balance).to(equal(U256(from: 3003)))
                    expect(childState.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))

                    expect(parentState.knownAccount(backend.address1)).to(beNil())
                    expect(childState.knownAccount(backend.address1)).to(beNil())

                    expect(childState.basic(address: backend.address1).balance).to(equal(U256.ZERO))
                    expect(parentState.knownAccount(backend.address1)).to(beNil())
                    expect(childState.knownAccount(backend.address1)?.basic.balance).to(equal(U256.ZERO))
                }

                it("Get basic for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    expect(parentState.knownAccount(backend.sender)).to(beNil())
                    expect(childState.knownAccount(backend.sender)).to(beNil())

                    parentState.touch(address: backend.sender)
                    expect(parentState.knownAccount(backend.sender)?.basic.balance).to(equal(U256(from: 3003)))
                    expect(childState.knownAccount(backend.sender)?.basic.balance).to(equal(U256(from: 3003)))

                    expect(parentState.knownAccount(backend.address1)).to(beNil())
                    expect(childState.knownAccount(backend.address1)).to(beNil())

                    childState.touch(address: backend.address1)
                    expect(parentState.knownAccount(backend.address1)).to(beNil())
                    expect(childState.knownAccount(backend.address1)?.basic.balance).to(equal(U256.ZERO))
                }
            }

            context("Storage Management") {
                let key1 = H256(from: U256(from: 10).toBigEndian)
                let val1 = H256(from: [UInt8](repeating: 0xff, count: 32))
                let expectedVal = H256(from: U256(from: 555).toBigEndian)

                it("should handle storage and resets for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    expect(state.knownStorage(address: backend.sender, key: backend.storageKey1)).to(beNil())
                    expect(state.knownStorage(address: backend.address1, key: key1)).to(beNil())

                    expect(state.storage(address: backend.sender, index: backend.storageKey1)).to(equal(expectedVal))
                    // Cashed value should be available in knownStorage after access
                    expect(state.knownStorage(address: backend.sender, key: backend.storageKey1)).to(equal(expectedVal))

                    // Set value and then reset
                    state.setStorage(address: backend.address1, key: key1, value: val1)
                    expect(state.knownStorage(address: backend.address1, key: key1)).to(equal(val1))
                    // Account was not cashed before at all
                    expect(state.knownAccount(backend.address1)?.reset).to(beNil())

                    // Account cashed
                    state.resetStorage(address: backend.address1)

                    expect(state.storages[backend.address1]).to(beNil())
                    expect(state.storage(address: backend.sender, index: backend.storageKey1)).to(equal(expectedVal))
                    expect(state.accounts[backend.address1]?.reset).to(beTrue())
                    // Reset account should return zero valued
                    expect(state.knownStorage(address: backend.address1, key: key1)).to(equal(H256.ZERO))
                }

                it("should handle storage and resets for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    expect(parentState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(beNil())
                    expect(childState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(beNil())

                    expect(parentState.storage(address: backend.sender, index: backend.storageKey1)).to(equal(expectedVal))
                    // Cashed value in parent state
                    expect(childState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(equal(expectedVal))

                    // Set value and then reset
                    parentState.setStorage(address: backend.sender, key: key1, value: val1)
                    expect(parentState.knownStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.knownStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(parentState.knownAccount(backend.sender)?.reset).to(beNil())
                    expect(childState.knownAccount(backend.sender)?.reset).to(beNil())

                    let val2 = H256(from: [UInt8](repeating: 0xee, count: 32))

                    childState.setStorage(address: backend.sender, key: backend.storageKey1, value: val2)
                    expect(parentState.knownStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(equal(val2))
                    expect(parentState.knownAccount(backend.sender)?.reset).to(beNil())
                    expect(childState.knownAccount(backend.sender)?.reset).to(beNil())

                    // Account cashed
                    parentState.resetStorage(address: backend.sender)

                    expect(parentState.storages[backend.sender]).to(beNil())
                    expect(parentState.accounts[backend.sender]?.reset).to(beTrue())
                    expect(parentState.knownStorage(address: backend.sender, key: key1)).to(equal(H256.ZERO))

                    expect(childState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(equal(val2))
                    expect(childState.accounts[backend.sender]?.reset).to(beNil())

                    childState.resetStorage(address: backend.sender)

                    expect(parentState.storages[backend.sender]).to(beNil())
                    expect(parentState.accounts[backend.sender]?.reset).to(beTrue())
                    expect(childState.storages[backend.sender]).to(beNil())
                    expect(childState.accounts[backend.sender]?.reset).to(beTrue())

                    expect(parentState.knownStorage(address: backend.sender, key: key1)).to(equal(H256.ZERO))
                    expect(childState.knownStorage(address: backend.sender, key: backend.storageKey1)).to(equal(H256.ZERO))
                }
            }

            context("Track create and deleted accounts state") {
                it("setDeleted, isDeleted") {
                    let backend = MockBackend()
                    let parent = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let child = MemoryState(metadata: parent.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    child.parent = parent

                    // Case 1: Inherited from parent
                    let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                    expect(parent.isDeleted(addr1)).to(beFalse())
                    expect(child.isDeleted(addr1)).to(beFalse())

                    parent.setDeleted(address: addr1)
                    expect(parent.isDeleted(addr1)).to(beTrue())
                    expect(child.isDeleted(addr1)).to(beTrue())

                    // Case 2: Set in child
                    let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))
                    child.setDeleted(address: addr2)
                    expect(parent.isDeleted(addr2)).to(beFalse())
                    expect(child.isDeleted(addr2)).to(beTrue())

                    // Case 3: Not deleted
                    let addr3 = H160(from: [UInt8](repeating: 0x03, count: 20))
                    expect(parent.isDeleted(addr3)).to(beFalse())
                    expect(child.isDeleted(addr3)).to(beFalse())
                }

                it("setCreated, isCreated") {
                    let backend = MockBackend()
                    let parent = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let child = MemoryState(metadata: parent.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    child.parent = parent

                    // Case 1: Inherited from parent
                    let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                    expect(parent.isCreated(addr1)).to(beFalse())
                    expect(child.isCreated(addr1)).to(beFalse())

                    parent.setCreated(address: addr1)
                    expect(parent.isCreated(addr1)).to(beTrue())
                    expect(child.isCreated(addr1)).to(beTrue())

                    // Case 2: Set in child
                    let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))
                    child.setCreated(address: addr2)
                    expect(parent.isCreated(addr2)).to(beFalse())
                    expect(child.isCreated(addr2)).to(beTrue())

                    // Case 3: Not created
                    let addr3 = H160(from: [UInt8](repeating: 0x03, count: 20))
                    expect(parent.isCreated(addr3)).to(beFalse())
                    expect(child.isCreated(addr3)).to(beFalse())
                }
            }

            context("Environmental Data") {
                it("gasPrice") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.gasPrice()).to(equal(U256(from: 333)))
                }

                it("origin") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.origin()).to(equal(backend.sender))
                }

                it("blockHash") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockHash(number: U256.ZERO)).to(equal(H256(from: U256(from: 100).toBigEndian)))
                }

                it("blockNumber") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockNumber()).to(equal(U256(from: 1000)))
                }

                it("blockCoinbase") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockCoinbase()).to(equal(backend.coinBase))
                }

                it("blockTimestamp") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockTimestamp()).to(equal(U256(from: 1234567890)))
                }

                it("blockDifficulty") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockDifficulty()).to(equal(U256(from: 999)))
                }

                it("blockRandomness") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockRandomness()).to(equal(H256(from: U256(from: 22).toBigEndian)))
                }

                it("blockGasLimit") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockGasLimit()).to(equal(U256(from: 8000000)))
                }

                it("blockBaseFeePerGas") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blockBaseFeePerGas()).to(equal(U256(from: 300)))
                }

                it("chainId") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.chainId()).to(equal(U256(from: 1)))
                }

                it("blobGasPrice") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.blobGasPrice()).to(equal(U128(from: 410)))
                }

                it("getBlobHash") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.getBlobHash(index: 0)).to(equal(U256(from: 601)))
                }

                it("exists") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.exists(address: backend.sender)).to(beFalse())

                    _ = state.getAccountAndTouch(backend.sender)
                    expect(state.exists(address: backend.sender)).to(beTrue())
                }

                it("isEmptyStorage") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.isEmptyStorage(address: backend.sender)).to(beTrue())

                    state.setStorage(address: backend.sender, key: backend.storageKey1, value: H256(from: U256(from: 555).toBigEndian))
                    expect(state.storage(address: backend.sender, index: backend.storageKey1)).to(equal(H256(from: U256(from: 555).toBigEndian)))
                    expect(state.isEmptyStorage(address: backend.sender)).to(beFalse())
                }

                it("originalStorage") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    expect(state.originalStorage(address: backend.sender, index: backend.storageKey1)).to(beNil())
                }

            }

            context("Handle transfers") {
                it("Transfer with OutOfFund and self transfer") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.address1).balance).to(equal(U256.ZERO))

                    let transfer1 = Transfer(source: backend.address1, target: backend.sender, value: U256(from: 50))
                    let res1 = state.transfer(transfer: transfer1)
                    expect(res1).to(beFailure { error in expect(error).to(equal(.OutOfFund)) })
                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.address1).balance).to(equal(U256.ZERO))

                    let transfer2 = Transfer(source: backend.sender, target: backend.sender, value: U256(from: 50))
                    let res2 = state.transfer(transfer: transfer2)
                    expect(res2).to(beSuccess())
                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                }

                it("Successful transfer") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 3003)))
                    expect(state.basic(address: backend.address1).balance).to(equal(U256.ZERO))

                    let transfer1 = Transfer(source: backend.sender, target: backend.address1, value: U256(from: 50))
                    let res = state.transfer(transfer: transfer1)
                    expect(res).to(beSuccess())
                    expect(state.basic(address: backend.sender).balance).to(equal(U256(from: 2953)))
                    expect(state.basic(address: backend.address1).balance).to(equal(U256(from: 50)))
                }
            }

            context("isEmpty logic") {
                let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))

                it("should identify empty accounts correctly") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // Account with balance is not empty
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: U256(from: 1), nonce: .ZERO), code: nil, reset: false)
                    expect(state.isEmpty(address: addr1)).to(beFalse())

                    // Account with no balance, no nonce, and empty code is empty
                    state.accounts[addr2] = StateAccount(basic: BasicAccount(balance: .ZERO, nonce: .ZERO), code: [], reset: false)
                    expect(state.isEmpty(address: addr2)).to(beTrue())
                }

                it("should determine if account is empty correctly") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // 1. Locally known: Has Balance
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: U256(from: 1), nonce: .ZERO), code: [], reset: false)
                    expect(state.isEmpty(address: addr1)).to(beFalse())

                    // 2. Locally known: Has Nonce
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: .ZERO, nonce: U256(from: 1)), code: [], reset: false)
                    expect(state.isEmpty(address: addr1)).to(beFalse())

                    // 3. Locally known: Has Code
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: .ZERO, nonce: .ZERO), code: [0x00], reset: false)
                    expect(state.isEmpty(address: addr1)).to(beFalse())

                    // 4. Locally known: Empty
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: .ZERO, nonce: .ZERO), code: [], reset: false)
                    expect(state.isEmpty(address: addr1)).to(beTrue())

                    // 5. Locally known: Empty with code nil
                    state.accounts[addr1] = StateAccount(basic: BasicAccount(balance: .ZERO, nonce: .ZERO), code: nil, reset: false)
                    expect(state.isEmpty(address: addr1)).to(beTrue())

                    // Not cashed
                    expect(state.isEmpty(address: backend.sender)).to(beFalse())
                    expect(state.isEmpty(address: addr2)).to(beTrue())
                }
            }

            context("TStorage Management") {
                let key1 = H256(from: U256(from: 10).toBigEndian)
                let val1 = H256(from: [UInt8](repeating: 0xf2, count: 32))
                let expectedVal = H256(from: U256(from: 555).toBigEndian)

                it("should handle tstorage for current state") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    expect(state.knownTStorage(address: backend.address1, key: key1)).to(beNil())
                    expect(state.getTStorage(address: backend.address1, key: key1)).to(equal(H256.ZERO))

                    state.setTStorage(address: backend.address1, key: key1, value: val1)
                    expect(state.knownTStorage(address: backend.address1, key: key1)).to(equal(val1))
                    expect(state.getTStorage(address: backend.address1, key: key1)).to(equal(val1))
                }

                it("should handle tstorage for substate") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    expect(parentState.knownTStorage(address: backend.sender, key: backend.storageKey1)).to(beNil())
                    expect(childState.knownTStorage(address: backend.sender, key: backend.storageKey1)).to(beNil())
                    expect(parentState.getTStorage(address: backend.sender, key: key1)).to(equal(H256.ZERO))
                    expect(childState.getTStorage(address: backend.sender, key: key1)).to(equal(H256.ZERO))

                    parentState.setTStorage(address: backend.sender, key: key1, value: val1)
                    expect(parentState.knownTStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.knownTStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(parentState.getTStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.getTStorage(address: backend.sender, key: key1)).to(equal(val1))

                    let val2 = H256(from: [UInt8](repeating: 0xee, count: 32))

                    childState.setTStorage(address: backend.sender, key: key1, value: val2)
                    expect(parentState.knownTStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.knownTStorage(address: backend.sender, key: key1)).to(equal(val2))
                    expect(parentState.getTStorage(address: backend.sender, key: key1)).to(equal(val1))
                    expect(childState.getTStorage(address: backend.sender, key: key1)).to(equal(val2))
                }
            }

            // TODO:
            context("Cold/Warm Access (EIP-2929)") {
                let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))

                it("should correctly identify cold vs warm addresses") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // Initially cold
                    expect(state.isCold(addr1)).to(beTrue())

                    // Mark as accessed
                    state.metadata.accessAddress(addr1)

                    expect(state.isCold(addr1)).to(beFalse())
                }

                it("should check cold status recursively in parent states") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    parentState.metadata.accessAddress(addr1)

                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    // addr1 is warm because it's accessed in parent
                    expect(childState.isCold(addr1)).to(beFalse())
                    // addr2 is cold everywhere
                    expect(childState.isCold(addr2)).to(beTrue())
                }
            }

            context("State Transitions (Enter/Exit)") {
                let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
                let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))

                it("should swap state correctly on enter") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    state.log(address: addr1, topics: [], data: [1, 2, 3])
                    state.enter(gasLimit: 5000, isStatic: false)

                    expect(state.parent).toNot(beNil())
                    expect(state.logs).to(beEmpty()) // New substate has empty logs
                    expect(state.parent?.logs.count).to(equal(1)) // Old logs moved to parent
                    expect(state.metadata.gasometer.limit).to(equal(5000))
                }

                it("should restore and merge state on exitCommit") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    state.enter(gasLimit: 8000, isStatic: false)

                    state.log(address: addr1, topics: [], data: [0xaa])
                    state.setCreated(address: addr2)

                    state.exitCommit()

                    expect(state.parent).to(beNil())
                    expect(state.logs.count).to(equal(1))
                    expect(state.isCreated(addr2)).to(beTrue())
                }
            }

            /*
             context("Account code state") {
                 it("should handle original storage lookups (knownOriginalStorage)") {
                     let backend = MockBackend()
                     let parent = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                     // Mock backend storage access via parent
                     // We need to inject into backend or parent to test the fallback
                     // MemoryState.knownOriginalStorage falls back to parent.knownOriginalStorage

                     let child = MemoryState(metadata: parent.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                     child.parent = parent

                     // Case 1: Account reset in child -> returns ZERO
                     child.resetStorage(address: addr1)
                     expect(child.knownOriginalStorage(addr1)).to(equal(H256.ZERO))

                     // Case 2: Normal lookup (mocks backend interaction via recursion)
                     // Since MockBackend.originalStorage returns value, and we didn't reset in a fresh state:
                     let freshState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                     // The MemoryState wrapper implementation of Backend calls knownOriginalStorage.
                     // If we call freshState.knownOriginalStorage directly:
                     // It returns parent?.knownOriginalStorage. If parent is nil, it returns nil.
                     expect(freshState.knownOriginalStorage(addr1)).to(beNil())
                 }
             }
             */
        }
    }
}
