
@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class StackSpec: QuickSpec {
    override class func spec() {
        describe("Stack type") {
            context("initialization") {
                it("should initialize with the correct limit") {
                    let stack = Stack(limit: 1024)
                    expect(stack.limit).to(equal(1024))
                    expect(stack.length).to(equal(0))
                }

                it("should initialize with the default limit") {
                    let stack = Stack()
                    expect(stack.limit).to(equal(Stack.STACK_LIMIT))
                    expect(stack.length).to(equal(0))
                }
            }

            context("push operation") {
                it("should push a value to the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 1))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 2))
                    expect(result2).to(beSuccess())
                    expect(stack.length).to(equal(2))
                }

                it("should return a StackOverflow error when pushing past the limit") {
                    var stack = Stack(limit: 1)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackOverflow))
                    })
                    expect(stack.length).to(equal(1))
                }
            }

            context("pop operation") {
                it("should pop a value from the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.pop()
                    expect(result2).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(0))
                }

                it("should return a StackUnderflow error when popping from an empty stack") {
                    var stack = Stack(limit: 1)
                    let result = stack.pop()
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }
            }

            context("popH256 operation") {
                it("should pop a value from the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.popH256()
                    expect(result2).to(beSuccess { value in
                        let expectValue = H256(from: U256(from: 10).toBigEndian)
                        expect(value).to(equal(expectValue))
                    })
                    expect(stack.length).to(equal(0))
                }

                it("should return a StackUnderflow error when popping from an empty stack") {
                    var stack = Stack(limit: 1)
                    let result = stack.pop()
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }
            }

            context("peek operation") {
                it("should return a values from the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    expect(stack.length).to(equal(2))

                    let result3 = stack.peek(indexFromTop: 1)
                    expect(result3).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    let result4 = stack.peek(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })
                    expect(stack.length).to(equal(2))
                }

                it("should return a StackUnderflow error when peeking an out of bounds index") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.peek(indexFromTop: 2)
                    expect(result2).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                    let result4 = stack.peek(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(1))
                }

                it("should return a StackUnderflow error when peeking from an empty stack") {
                    let stack = Stack(limit: 2)
                    let result = stack.peek(indexFromTop: 0)
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }
            }

            context("peek H256 operation") {
                it("should return a values from the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    expect(stack.length).to(equal(2))

                    let result3 = stack.peekH256(indexFromTop: 1)
                    expect(result3).to(beSuccess { value in
                        let expectedValue = H256(from: U256(from: 10).toBigEndian)
                        expect(value).to(equal(expectedValue))
                    })
                    let result4 = stack.peekH256(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        let expectedValue = H256(from: U256(from: 20).toBigEndian)
                        expect(value).to(equal(expectedValue))
                    })
                    expect(stack.length).to(equal(2))
                }

                it("should return a StackUnderflow error when peeking an out of bounds index") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.peekH256(indexFromTop: 2)
                    expect(result2).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                    let result4 = stack.peekH256(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        let expectedValue = H256(from: U256(from: 10).toBigEndian)
                        expect(value).to(equal(expectedValue))
                    })
                    expect(stack.length).to(equal(1))
                }

                it("should return a StackUnderflow error when peeking from an empty stack") {
                    let stack = Stack(limit: 2)
                    let result = stack.peekH256(indexFromTop: 0)
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }
            }

            context("peek UInt operation") {
                it("should return a values from the stack successfully") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    expect(stack.length).to(equal(2))

                    let result3 = stack.peekUInt(indexFromTop: 1)
                    expect(result3).to(beSuccess { value in
                        expect(value).to(equal(10))
                    })
                    let result4 = stack.peekUInt(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(20))
                    })
                    expect(stack.length).to(equal(2))
                }

                it("should return a StackUnderflow error when peeking an out of bounds index") {
                    var stack = Stack(limit: 2)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.peekUInt(indexFromTop: 2)
                    expect(result2).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                    let result4 = stack.peekUInt(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(10))
                    })
                    expect(stack.length).to(equal(1))
                }

                it("should return a StackUnderflow error when peeking from an empty stack") {
                    let stack = Stack(limit: 2)
                    let result = stack.peekUInt(indexFromTop: 0)
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }
            }

            context("set operation") {
                it("should successfully set a value at the top of the stack (index 0)") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    let result3 = stack.push(value: U256(from: 30))
                    expect(result3).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result5 = stack.peek(indexFromTop: 0)
                    expect(result5).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 30)))
                    })

                    let result6 = stack.set(indexFromTop: 0, value: U256(from: 999))
                    expect(result6).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result7 = stack.peek(indexFromTop: 0)
                    expect(result7).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 999)))
                    })
                    let result8 = stack.peek(indexFromTop: 1)
                    expect(result8).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })
                    let result9 = stack.peek(indexFromTop: 2)
                    expect(result9).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(3))
                }

                it("should successfully set a value in the middle of the stack") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    let result3 = stack.push(value: U256(from: 30))
                    expect(result3).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result5 = stack.peek(indexFromTop: 1)
                    expect(result5).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })

                    let result6 = stack.set(indexFromTop: 1, value: U256(from: 999))
                    expect(result6).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result7 = stack.peek(indexFromTop: 0)
                    expect(result7).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 30)))
                    })
                    let result8 = stack.peek(indexFromTop: 1)
                    expect(result8).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 999)))
                    })
                    let result9 = stack.peek(indexFromTop: 2)
                    expect(result9).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(3))
                }

                it("should successfully set a value at the bottom of the stack") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    let result3 = stack.push(value: U256(from: 30))
                    expect(result3).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result5 = stack.peek(indexFromTop: 2)
                    expect(result5).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })

                    let result6 = stack.set(indexFromTop: 2, value: U256(from: 999))
                    expect(result6).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result7 = stack.peek(indexFromTop: 0)
                    expect(result7).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 30)))
                    })
                    let result8 = stack.peek(indexFromTop: 1)
                    expect(result8).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })
                    let result9 = stack.peek(indexFromTop: 2)
                    expect(result9).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 999)))
                    })
                }

                it("should return a StackUnderflow error when trying to set a value out of bounds") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    let result3 = stack.push(value: U256(from: 30))
                    expect(result3).to(beSuccess())
                    expect(stack.length).to(equal(3))

                    let result4 = stack.set(indexFromTop: 3, value: U256(from: 555))
                    expect(result4).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })

                    let result5 = stack.peek(indexFromTop: 0)
                    expect(result5).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 30)))
                    })
                    let result6 = stack.peek(indexFromTop: 1)
                    expect(result6).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })
                    let result7 = stack.peek(indexFromTop: 2)
                    expect(result7).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(3))
                }

                it("should return a StackUnderflow error when trying to set a value in an empty stack") {
                    var stack = Stack(limit: 3)
                    expect(stack.length).to(equal(0))
                    let result = stack.set(indexFromTop: 0, value: U256(from: 555))
                    expect(result).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })
                }

                it("should handle setting values in a stack with only one element") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    expect(stack.length).to(equal(1))

                    let result2 = stack.peek(indexFromTop: 0)
                    expect(result2).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    let result3 = stack.set(indexFromTop: 0, value: U256(from: 111))
                    expect(result3).to(beSuccess())
                    let result4 = stack.peek(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 111)))
                    })
                }

                it("should return StackUnderflow error if index is negative") {
                    var stack = Stack(limit: 3)
                    let result1 = stack.push(value: U256(from: 10))
                    expect(result1).to(beSuccess())
                    let result2 = stack.push(value: U256(from: 20))
                    expect(result2).to(beSuccess())
                    expect(stack.length).to(equal(2))

                    let result3 = stack.set(indexFromTop: -1, value: U256(from: 555))
                    expect(result3).to(beFailure { error in
                        expect(error).to(matchError(Machine.ExitError.StackUnderflow))
                    })

                    let result4 = stack.peek(indexFromTop: 0)
                    expect(result4).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 20)))
                    })
                    let result5 = stack.peek(indexFromTop: 1)
                    expect(result5).to(beSuccess { value in
                        expect(value).to(equal(U256(from: 10)))
                    })
                    expect(stack.length).to(equal(2))
                }
            }
        }
    }
}
