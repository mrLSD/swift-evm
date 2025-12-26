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
                    expect(memory.effectiveLength).to(equal(0))
                }
            }

            context("length after resize") {
                it("should return the correct length for double resize with same length") {
                    let memory = Memory(limit: 100)
                    expect(memory.effectiveLength).to(equal(0))

                    let res = memory.resize(end: 50)
                    expect(res).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))

                    let res2 = memory.resize(end: 50)
                    expect(res2).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                }

                it("should return the correct length for double resize with different length") {
                    let memory = Memory(limit: 100)
                    expect(memory.effectiveLength).to(equal(0))

                    let res = memory.resize(end: 50)
                    expect(res).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))

                    let res2 = memory.resize(end: 70)
                    expect(res2).to(beTrue())
                    expect(memory.effectiveLength).to(equal(96))
                }
            }

            context("resize offset") {
                it("zero size") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 1000, size: 0)
                    expect(res1).to(beFalse())
                    expect(memory.effectiveLength).to(equal(0))
                }

                it("should increase the size and fill new bytes with zeros") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 30, size: 10)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 30, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))
                }

                it("double resize") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 30, size: 10)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 30, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))

                    let res2 = memory.resize(offset: 50, size: 10)
                    expect(res2).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 50, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))

                    let res3 = memory.resize(offset: 60, size: 10)
                    expect(res3).to(beTrue())
                    expect(memory.effectiveLength).to(equal(96))
                    expect(memory.get(offset: 50, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))
                }

                it("should not decrease the size") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 30, size: 10)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 30, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))

                    let res2 = memory.resize(offset: 0, size: 10)
                    expect(res2).to(equal(true))
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 0, size: 10)).to(equal([UInt8](repeating: 0, count: 10)))
                }

                it("check is new size is filled with zeros") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 3)).to(equal([0, 0, 0]))

                    expect(memory.set(offset: 0, value: [7, 7, 7], size: 3)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 3)).to(equal([7, 7, 7]))
                    expect(memory.get(offset: 3, size: 29)).to(equal([UInt8](repeating: 0, count: 29)))

                    expect(memory.set(offset: 3, value: [UInt8](repeating: 7, count: 29), size: 29)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 7, count: 32)))

                    let res2 = memory.resize(offset: 30, size: 3)
                    expect(res2).to(beTrue())
                    expect(memory.effectiveLength).to(equal(64))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 7, count: 32)))
                    expect(memory.get(offset: 32, size: 32)).to(equal([UInt8](repeating: 0, count: 32)))
                }

                it("resize with Int.max offset returns false") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: Int.max, size: 3)
                    expect(res1).to(beFalse())
                    expect(memory.effectiveLength).to(equal(0))
                }
            }

            context("Get memory method") {
                it("zero size") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 0)).to(equal([]))
                }

                it("offset beyond the end") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 4, size: 1)).to(equal([0]))
                }
            }

            context("Set memory method") {
                it("zero size") {
                    let memory = Memory()
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.set(offset: 0, value: [1, 1], size: 0)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 3)).to(equal([0, 0, 0]))
                }

                it("size beyond the limit") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.set(offset: 100, value: [1, 1], size: 2)).to(beFailure(equal(Machine.ExitReason.Error(.MemoryOperation(.SetLimitExceeded)))))

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 3)).to(equal([0, 0, 0]))
                }

                it("success set") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.set(offset: 1, value: [1, 1, 1], size: 3)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 5)).to(equal([0, 1, 1, 1, 0]))
                }

                it("size greater than value") {
                    let memory = Memory(limit: 100)
                    expect(memory.set(offset: 0, value: [UInt8](repeating: 1, count: 32), size: 32)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 1, count: 32)))

                    expect(memory.set(offset: 1, value: [2, 2, 2], size: 5)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 7)).to(equal([1, 2, 2, 2, 0, 0, 1]))
                }

                it("value greater than size") {
                    let memory = Memory(limit: 100)
                    expect(memory.set(offset: 0, value: [UInt8](repeating: 1, count: 32), size: 32)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 1, count: 32)))

                    expect(memory.set(offset: 1, value: [2, 2, 2], size: 2)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 7)).to(equal([1, 2, 2, 1, 1, 1, 1]))
                }
            }

            context("Copy memory method") {
                it("zero size") {
                    let memory = Memory()
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copy(srcOffset: 0, dstOffset: 2, size: 0)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 0, count: 32)))
                }

                it("srcOffset == dstOffset") {
                    let memory = Memory()
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copy(srcOffset: 2, dstOffset: 2, size: 2)).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 0, count: 32)))
                }

                it("size beyond the limit") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copy(srcOffset: 2, dstOffset: 3, size: 100)).to(beFailure(equal(Machine.ExitReason.Error(.MemoryOperation(.CopyLimitExceeded)))))
                    expect(memory.effectiveLength).to(equal(32))
                }

                it("copy success") {
                    let memory = Memory()
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.set(offset: 0, value: [UInt8](repeating: 1, count: 16), size: 16)).to(beSuccess())
                    expect(memory.set(offset: 16, value: [UInt8](repeating: 2, count: 16), size: 16)).to(beSuccess())

                    expect(memory.get(offset: 0, size: 16)).to(equal([UInt8](repeating: 1, count: 16)))
                    expect(memory.get(offset: 16, size: 16)).to(equal([UInt8](repeating: 2, count: 16)))
                    expect(memory.effectiveLength).to(equal(32))

                    expect(memory.copy(srcOffset: 0, dstOffset: 16, size: 8)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 24)).to(equal([UInt8](repeating: 1, count: 24)))
                    expect(memory.get(offset: 24, size: 8)).to(equal([UInt8](repeating: 2, count: 8)))
                    expect(memory.effectiveLength).to(equal(32))

                    expect(memory.copy(srcOffset: 24, dstOffset: 0, size: 4)).to(beSuccess())
                    expect(memory.get(offset: 0, size: 4)).to(equal([UInt8](repeating: 2, count: 4)))
                    expect(memory.get(offset: 4, size: 20)).to(equal([UInt8](repeating: 1, count: 20)))
                    expect(memory.get(offset: 24, size: 8)).to(equal([UInt8](repeating: 2, count: 8)))
                    expect(memory.effectiveLength).to(equal(32))
                }
            }

            context("CopyData memory method") {
                it("zero size") {
                    let memory = Memory()
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copyData(memoryOffset: 1, dataOffset: 2, size: 0, data: [1])).to(beSuccess())

                    expect(memory.effectiveLength).to(equal(32))
                    expect(memory.get(offset: 0, size: 32)).to(equal([UInt8](repeating: 0, count: 32)))
                }

                it("destOffset > data count") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copyData(memoryOffset: 1, dataOffset: 2, size: 1, data: [1])).to(beFailure(equal(Machine.ExitReason.Error(.MemoryOperation(.CopyDataOffsetOutOfBounds)))))
                    expect(memory.effectiveLength).to(equal(32))
                }

                it("memory offset + size > limit") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.copyData(memoryOffset: 100, dataOffset: 0, size: 1, data: [1])).to(beFailure(equal(Machine.ExitReason.Error(.MemoryOperation(.CopyDataLimitExceeded)))))
                    expect(memory.effectiveLength).to(equal(32))
                }

                it("copyData success") {
                    let memory = Memory(limit: 100)
                    let res1 = memory.resize(offset: 0, size: 3)
                    expect(res1).to(beTrue())
                    expect(memory.set(offset: 0, value: [UInt8](repeating: 1, count: 16), size: 16)).to(beSuccess())
                    expect(memory.set(offset: 16, value: [UInt8](repeating: 2, count: 16), size: 16)).to(beSuccess())

                    expect(memory.get(offset: 0, size: 16)).to(equal([UInt8](repeating: 1, count: 16)))
                    expect(memory.get(offset: 16, size: 16)).to(equal([UInt8](repeating: 2, count: 16)))
                    expect(memory.effectiveLength).to(equal(32))

                    expect(memory.copyData(memoryOffset: 5, dataOffset: 2, size: 3, data: [3, 3, 3, 3, 3])).to(beSuccess())
                    expect(memory.get(offset: 0, size: 5)).to(equal([UInt8](repeating: 1, count: 5)))
                    expect(memory.get(offset: 5, size: 3)).to(equal([UInt8](repeating: 3, count: 3)))
                    expect(memory.get(offset: 8, size: 8)).to(equal([UInt8](repeating: 1, count: 8)))
                    expect(memory.get(offset: 16, size: 16)).to(equal([UInt8](repeating: 2, count: 16)))
                    expect(memory.effectiveLength).to(equal(32))

                    expect(memory.copyData(memoryOffset: 20, dataOffset: 2, size: 5, data: [3, 3, 3, 3, 3])).to(beSuccess())
                    expect(memory.get(offset: 0, size: 5)).to(equal([UInt8](repeating: 1, count: 5)))
                    expect(memory.get(offset: 5, size: 3)).to(equal([UInt8](repeating: 3, count: 3)))
                    expect(memory.get(offset: 8, size: 8)).to(equal([UInt8](repeating: 1, count: 8)))
                    expect(memory.get(offset: 16, size: 4)).to(equal([UInt8](repeating: 2, count: 4)))
                    expect(memory.get(offset: 20, size: 3)).to(equal([UInt8](repeating: 3, count: 3)))
                    expect(memory.get(offset: 23, size: 2)).to(equal([UInt8](repeating: 0, count: 2)))
                    expect(memory.get(offset: 25, size: 7)).to(equal([UInt8](repeating: 2, count: 7)))
                    expect(memory.effectiveLength).to(equal(32))
                }
            }

            context("ceil32 method") {
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

                it("overflow operation") {
                    expect(Memory.ceil32(Int.max)).to(equal(Int.max - 31))
                }
            }

            context("numWords method") {
                it("should return the same value if it is a multiple of 32") {
                    expect(Memory.numWords(32)).to(equal(1))
                    expect(Memory.numWords(64)).to(equal(2))
                    expect(Memory.numWords(0)).to(equal(0))
                }

                it("should return the next multiple of 32 if the value is not a multiple of 32") {
                    expect(Memory.numWords(1)).to(equal(1))
                    expect(Memory.numWords(31)).to(equal(1))
                    expect(Memory.numWords(33)).to(equal(2))
                    expect(Memory.numWords(63)).to(equal(2))
                    expect(Memory.numWords(65)).to(equal(3))
                }

                it("overflow operation") {
                    expect(Memory.numWords(Int.max)).to(equal(Int.max / 32))
                }
            }
        }
    }
}
