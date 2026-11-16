@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class ExecutorSpec: QuickSpec {
    override class func spec() {
        describe("Executor") {
            context("authorityCode") {
                let a = H160(from: [UInt8](repeating: 0x11, count: 20))
                let b = H160(from: [UInt8](repeating: 0x22, count: 20))
                let c = H160(from: [UInt8](repeating: 0x33, count: 20))
                let marker: [UInt8] = [0xef, 0x01, 0x00] + b.BYTES

                it("returns the designation unchanged before Prague without caching or warming its target") {
                    let forks = HardFork.allCases.prefix(while: { $0 != .Prague })
                    expect(forks.last).to(equal(.Cancun))
                    for fork in forks {
                        let backend = MockBackend()
                        backend.codes[a] = marker
                        backend.codes[b] = [0x00]
                        let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: fork)
                        let before = state.metadata
                        let executor = Executor(state: state, hardFork: fork)

                        expect(executor.authorityCode(codeAddress: a)).to(equal(marker))
                        expect(backend.codeRequests).to(equal([a]))
                        expect(state.metadata).to(equal(before))
                        expect(state.accounts).to(beEmpty())
                        expect(backend.basicRequests).to(beEmpty())
                    }
                }

                it("resolves exactly one level from Prague and warms only the delegate") {
                    let forks = HardFork.allCases.drop(while: { $0 != .Prague })
                    expect(forks.first).to(equal(.Prague))
                    let cases: [(code: [UInt8], targetCode: [UInt8], expected: [UInt8], requests: [H160], warm: [H160])] = [
                        ([0x60, 0x01], [], [0x60, 0x01], [a], []),
                        ([], [], [], [a], []),
                        (marker, [0x60, 0x02], [0x60, 0x02], [a, b], [b]),
                        (marker, [0xef, 0x01, 0x00] + c.BYTES, [0xef, 0x01, 0x00] + c.BYTES, [a, b], [b]),
                        ([0xef, 0x01, 0x00] + a.BYTES, [], [0xef, 0x01, 0x00] + a.BYTES, [a, a], [a]),
                        (marker, [], [], [a, b], [b]),
                        (Array(marker.dropLast()), [], Array(marker.dropLast()), [a], []),
                        (marker + [0], [], marker + [0], [a], []),
                        ([0xef, 0x01, 0x01] + b.BYTES, [], [0xef, 0x01, 0x01] + b.BYTES, [a], []),
                    ]
                    for fork in forks {
                        for (index, item) in cases.enumerated() {
                            let backend = MockBackend()
                            backend.codes[a] = item.code
                            if !item.targetCode.isEmpty {
                                backend.codes[b] = item.targetCode
                            }
                            let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: fork)
                            let before = state.metadata
                            let executor = Executor(state: state, hardFork: fork)
                            let detail = "fork \(fork), case \(index)"

                            expect(executor.authorityCode(codeAddress: a)).to(equal(item.expected), description: detail)
                            expect(backend.codeRequests).to(equal(item.requests), description: detail)
                            expect(state.metadata.accessedData()?.addresses).to(equal(Set(item.warm)), description: detail)
                            expect(state.metadata.gasometer).to(equal(before.gasometer))
                            expect(state.metadata.depth).to(beNil())
                            expect(state.accounts).to(beEmpty())
                            expect(state.logs).to(beEmpty())
                            expect(state.parent).to(beNil())
                            expect(backend.basicRequests).to(beEmpty())
                            expect(backend.codeHashRequests).to(beEmpty())
                            expect(backend.hasCodeRequests).to(beEmpty())
                        }
                    }
                }

                it("uses local code and preserves an already warm delegate") {
                    for fork in HardFork.allCases.drop(while: { $0 != .Prague }) {
                        for localAddress in [a, b] {
                            for localCode: [UInt8] in [[], [0x60, 0x07]] {
                                let backend = MockBackend()
                                backend.codes[a] = marker
                                backend.codes[b] = [0xfe]
                                let state = MemoryState(gasLimit: 1000, backend: backend, hardFork: fork)
                                state.setCode(address: localAddress, code: localCode)
                                state.metadata.accessAddress(b)
                                backend.basicRequests = []
                                let accounts = state.accounts
                                let gas = state.metadata.gasometer
                                let executor = Executor(state: state, hardFork: fork)

                                expect(executor.authorityCode(codeAddress: a)).to(equal(localCode))
                                expect(backend.codeRequests).to(equal(localAddress == a ? [] : [a]))
                                expect(state.metadata.accessedData()?.addresses).to(equal(Set([b])))
                                expect(state.accounts).to(equal(accounts))
                                expect(state.metadata.gasometer).to(equal(gas))
                                expect(backend.basicRequests).to(beEmpty())
                                expect(backend.codeHashRequests).to(beEmpty())
                                expect(backend.hasCodeRequests).to(beEmpty())
                            }
                        }
                    }
                }
            }

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
