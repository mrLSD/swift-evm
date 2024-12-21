@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InterpreterMemorySpec: QuickSpec {
    override class func spec() {
        describe("Interpreter Memory") {
            context("initialization") {
                it("should have a length of 0 after initialization") {
                    let memory = Memory(limit: 100)
                    expect(memory.length).to(equal(0))
                }
            }

            context("length after resize") {
                it("should return the correct length") {
                    var memory = Memory(limit: 100)
                    expect(memory.length).to(equal(0))

                    memory.resize(size: 50)
                    expect(memory.length).to(equal(50))
                }
            }

            context("resize method") {
                it("should increase the size and fill new bytes with zeros") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    expect(memory.length).to(equal(10))
                    expect(memory.get(range: 0..<10)).to(equal([UInt8](repeating: 0, count: 10)))

                    memory.set(range: 0..<10, with: [UInt8](repeating: 5, count: 10))
                    memory.resize(size: 15)
                    expect(memory.length).to(equal(15))
                    expect(memory.get(range: 0..<10)).to(equal([UInt8](repeating: 5, count: 10)))
                    expect(memory.get(range: 10..<15)).to(equal([UInt8](repeating: 0, count: 5)))
                }

                it("should not decrease the size") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 20)
                    memory.set(range: 0..<20, with: [UInt8](repeating: 1, count: 20))
                    memory.resize(size: 10)
                    expect(memory.length).to(equal(20))
                    expect(memory.get(range: 0..<20)).to(equal([UInt8](repeating: 1, count: 20)))
                }

                it("should not change the size if the new size is equal to the current size") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 30)
                    memory.set(range: 0..<30, with: [UInt8](repeating: 2, count: 30))
                    memory.resize(size: 30)
                    expect(memory.length).to(equal(30))
                    expect(memory.get(range: 0..<30)).to(equal([UInt8](repeating: 2, count: 30)))
                }
            }

            context("set(range:with:) method") {
                it("should correctly set data within the specified range") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    memory.set(range: 0..<10, with: [UInt8](repeating: 3, count: 10))

                    memory.set(range: 2..<5, with: [UInt8](repeating: 7, count: 3))
                    expect(memory.get(range: 0..<10)).to(equal([3, 3, 7, 7, 7, 3, 3, 3, 3, 3]))
                }

                it("should trigger an assertion when the data length does not match the range length") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    memory.set(range: 0..<10, with: [UInt8](repeating: 3, count: 10))

                    expect {
                        memory.set(range: 0..<5, with: [UInt8](repeating: 1, count: 4))
                    }.to(throwAssertion())
                }

                it("should trigger an assertion when the range is out of memory bounds") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    memory.set(range: 0..<10, with: [UInt8](repeating: 3, count: 10))

                    expect {
                        memory.set(range: 8..<12, with: [UInt8](repeating: 1, count: 4))
                    }.to(throwAssertion())
                }
            }

            context("get(range:) method") {
                it("should return correct data for a valid range") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    memory.set(range: 0..<10, with: [UInt8](repeating: 4, count: 10))
                    let data = memory.get(range: 3..<7)

                    expect(data).to(equal([4, 4, 4, 4]))
                }

                it("should trigger an assertion when the range is out of memory bounds") {
                    var memory = Memory(limit: 100)
                    memory.resize(size: 10)
                    memory.set(range: 0..<10, with: [UInt8](repeating: 4, count: 10))

                    expect {
                        _ = memory.get(range: -1..<5)
                    }.to(throwAssertion())
                    expect {
                        _ = memory.get(range: 5..<15)
                    }.to(throwAssertion())
                }
            }

            // Testing the static ceil32(_:) method
            context("static ceil32 method") {
                it("should return the same value if it is a multiple of 32") {
                    expect(Memory.ceil32(32)).to(equal(32))
                    expect(Memory.ceil32(64)).to(equal(64))
                    expect(Memory.ceil32(0)).to(equal(0))
                }

                it("should return the next multiple of 32 if the value is not a multiple of 32") {
                    expect(Memory.ceil32(1)).to(equal(32))
                    expect(Memory.ceil32(31)).to(equal(32))
                    expect(Memory.ceil32(33)).to(equal(64))
                    expect(Memory.ceil32(63)).to(equal(64))
                    expect(Memory.ceil32(65)).to(equal(96))
                }
            }
        }
    }
}
