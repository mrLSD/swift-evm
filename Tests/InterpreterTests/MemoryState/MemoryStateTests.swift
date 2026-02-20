@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

// MARK: - Mock Backend

final class MockBackend: Backend {
    var accounts: [H160: BasicAccount] = [:]
    var codes: [H160: [UInt8]] = [:]
    var storages: [H160: [H256: H256]] = [:]

    func gasPrice() -> U256 {
        .ZERO
    }

    func origin() -> H160 {
        .ZERO
    }

    func blockHash(number: U256) -> H256 {
        .ZERO
    }

    func blockNumber() -> U256 {
        .ZERO
    }

    func blockCoinbase() -> H160 {
        .ZERO
    }

    func blockTimestamp() -> U256 {
        .ZERO
    }

    func blockDifficulty() -> U256 {
        .ZERO
    }

    func blockRandomness() -> H256? {
        nil
    }

    func blockGasLimit() -> U256 {
        .ZERO
    }

    func blockBaseFeePerGas() -> U256 {
        .ZERO
    }

    func chainId() -> U256 {
        U256(from: 1)
    }

    func blobGasPrice() -> U128 {
        U128.ZERO
    }

    func getBlobHash(index: UInt) -> U256? {
        nil
    }

    func exists(address: H160) -> Bool {
        accounts[address] != nil
    }

    func basic(address: H160) -> BasicAccount {
        accounts[address] ?? BasicAccount(balance: U256(from: 10), nonce: U256(from: 20))
    }

    func code(address: H160) -> [UInt8] {
        if codes[address] == nil {
            codes[address] = [UInt8](repeating: 0x60, count: 10)
        }
        return codes[address] ?? []
    }

    func storage(address: H160, index: H256) -> H256 {
        if storages[address] == nil {
            var storage: [H256: H256] = [:]
            storage[H256.ZERO] = H256(from: [123])
            storages[address] = storage
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
            let addr1 = H160(from: [UInt8](repeating: 0x01, count: 20))
            let addr2 = H160(from: [UInt8](repeating: 0x02, count: 20))
            let key1 = H256.ZERO
            let val1 = H256(from: [UInt8](repeating: 0xff, count: 32))

            context("Account lookups and Caching") {
                it("should fetch account from backend and cache it locally") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // First call - triggers getAccountAndTouch
                    let acc = state.getAccountAndTouch(addr1)
                    expect(acc.basic.balance).to(equal(U256(from: 10)))

                    // Modify locally
                    state.accounts[addr1]?.basic.setBalance(U256(from: 2000))

                    // Verify local state changed but backend remains same
                    expect(state.knownBasic(addr1)?.balance).to(equal(U256(from: 2000)))
                    expect(backend.basic(address: addr1).balance).to(equal(U256(from: 10)))
                }

                it("should lookup account recursively in parent states") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    parentState.accounts[addr1] = StateAccount(basic: BasicAccount(balance: U256(from: 500), nonce: .ZERO), code: nil, reset: false)

                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    expect(childState.knownAccount(addr1)).toNot(beNil())
                    expect(childState.knownBasic(addr1)?.balance).to(equal(U256(from: 500)))
                }
            }

            context("Storage Management") {
                it("should handle storage resets correctly") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // Set value and then reset
                    state.setStorage(address: addr1, key: key1, value: val1)
                    expect(state.knownStorage(address: addr1, key: key1)).to(equal(val1))

                    state.resetStorage(address: addr1)

                    expect(state.storages[addr1]).to(beNil())
                    expect(state.accounts[addr1]?.reset).to(beTrue())
                    expect(state.knownStorage(address: addr1, key: key1)).to(equal(H256.ZERO))
                }

                it("should return ZERO for storage if account is marked reset, even if parent has value") {
                    let backend = MockBackend()
                    let parentState = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)
                    parentState.setStorage(address: addr1, key: key1, value: val1)

                    let childState = MemoryState(metadata: parentState.metadata.spitChild(gasLimit: 5000, isStatic: false), backend: backend)
                    childState.parent = parentState

                    _ = childState.getAccountAndTouch(addr1)
                    childState.accounts[addr1]?.reset = true

                    expect(childState.knownStorage(address: addr1, key: key1)).to(equal(H256.ZERO))
                }
            }

            context("Cold/Warm Access (EIP-2929)") {
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

            context("Nonce and Balance Mutations") {
                it("should increment nonce and handle overflow") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 10000, backend: backend, hardFork: .Berlin)

                    // Normal increment
                    _ = state.incNonce(address: addr1)
                    expect(state.knownAccount(addr1)?.basic.nonce).to(equal(U256(from: 21)))

                    // Mock max nonce
                    state.accounts[addr1]?.basic.nonce = U256(from: UInt64.max)
                    let result = state.incNonce(address: addr1)

                    expect(result).to(beFailure())
                }
            }

            context("isEmpty logic") {
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
            }
        }
    }
}
