@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ExecutorSpec: QuickSpec {
    override class func spec() {
        describe("Executor") {
            context("initialization") {
                it("keeps the given state by identity and leaves it untouched") {
                    let backend = MockBackend()
                    let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: .Berlin)
                    let executor = Executor(state: state, hardFork: .Berlin, memoryLimit: 32)

                    expect(executor.state === state).to(beTrue())
                    expect(state.parent).to(beNil())
                    expect(state.accounts).to(beEmpty())
                    expect(state.metadata.gasometer.remaining).to(equal(1000))
                    expect(state.metadata.depth).to(beNil())
                    expect(backend.basicRequests).to(beEmpty())
                    expect(backend.codeRequests).to(beEmpty())
                    expect(backend.codeHashRequests).to(beEmpty())
                    expect(backend.hasCodeRequests).to(beEmpty())
                }

                it("stores the explicit hard fork without substituting the default") {
                    expect(HardFork.latest()).toNot(equal(.Frontier))
                    for fork in HardFork.allCases {
                        let state = MemoryState(gasLimit: 0, backend: MockBackend(), hardFork: fork)
                        let executor = Executor(state: state, hardFork: fork, memoryLimit: 0)

                        expect(executor.hardFork).to(equal(fork), description: "fork \(fork)")
                    }
                }

                it("stores an explicit memory limit, including the maximum") {
                    for limit in [0, 1 << 20, Int.max] {
                        let state = MemoryState(gasLimit: 0, backend: MockBackend(), hardFork: .Frontier)
                        let executor = Executor(state: state, hardFork: .Frontier, memoryLimit: limit)

                        expect(executor.memoryLimit).to(equal(limit), description: "limit \(limit)")
                    }
                }

                it("defaults the memory limit to Int.max in every hard fork, as for a machine without a limit") {
                    for fork in HardFork.allCases {
                        let state = MemoryState(gasLimit: 0, backend: MockBackend(), hardFork: fork)
                        let executor = Executor(state: state, hardFork: fork)

                        expect(executor.memoryLimit).to(equal(Int.max), description: "fork \(fork)")
                        expect(executor.memoryLimit).to(equal(Memory().limit), description: "fork \(fork)")
                    }
                }

                it("limits the call depth to 1024") {
                    expect(Executor.callStackLimit).to(equal(1024))
                }

                it("shares one state between executors and keeps different states apart") {
                    let shared = MemoryState(gasLimit: 0, backend: MockBackend(), hardFork: .Osaka)
                    let other = MemoryState(gasLimit: 0, backend: MockBackend(), hardFork: .Osaka)
                    let first = Executor(state: shared, hardFork: .Osaka, memoryLimit: 0)
                    let second = Executor(state: shared, hardFork: .Osaka, memoryLimit: 0)
                    let third = Executor(state: other, hardFork: .Osaka, memoryLimit: 0)

                    expect(first.state === second.state).to(beTrue())
                    expect(first.state === third.state).to(beFalse())
                }
            }
        }
    }
}
