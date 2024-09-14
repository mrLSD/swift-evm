import PrimitiveTypes

/// EVM Machine Stack
public struct Stack {
    /// Stack data
    private var data: [U256] = []
    /// Stack limit
    public let limit: Int
    /// Stacke length
    public var length: Int { self.data.count }

    init(limit: Int) {
        self.limit = limit
    }

    /// Push `U256` value to the Stack. Return error if it's reach limit.
    mutating func push(value: U256) -> Machine.ExitError? {
        // Check stack overflow
        if self.data.count + 1 > self.limit {
            return .StackOverflow
        }
        self.data.append(value)
        return nil
    }

    /// Pop `U256` value from the Stack
    mutating func pop() -> Result<U256, Machine.ExitError> {
        guard let value = self.data.popLast() else {
            // Return error, if stack is empty
            return .failure(.StackUnderflow)
        }
        return .success(value)
    }

    /// Pop `H256` value from the Stack
    mutating func pop() -> Result<H256, Machine.ExitError> {
        guard let value = self.data.popLast() else {
            // Return error, if stack is empty
            return .failure(.StackUnderflow)
        }
        return .success(H256(from: value.toBigEndian))
    }

    /// Peeks `U256` value at a given index from the top of the stack.
    /// The top of the stack is at index `0`. If the index is too large,
    /// `ExitError.stackUnderflow` is returned.
    ///
    /// - Parameter indexFromTop: The index from the top of the stack.
    /// - Returns: A `Result` containing the `U256` value if successful, or an `ExitError` if an error occurs.
    func peek(indexFromTop: Int) -> Result<U256, Machine.ExitError> {
        // Ensure the index is non-negative and within the bounds of the Stack data array
        guard indexFromTop >= 0, indexFromTop < self.data.count else {
            return .failure(.StackUnderflow)
        }
        // Calculate the actual index in the array
        let index = self.data.count - indexFromTop - 1
        return .success(self.data[index])
    }

    /// Peeks `H256` value at a given index from the top of the stack (converts it to `H256`).
    /// The top of the stack is at index `0`. If the index is too large,
    /// `ExitError.stackUnderflow` is returned.
    ///
    /// - Parameter indexFromTop: The index from the top of the stack.
    /// - Returns: A `Result` containing the `H256` value if successful, or an `ExitError` if an error occurs.
    func peekH256(indexFromTop: Int) -> Result<H256, Machine.ExitError> {
        self.peek(indexFromTop: indexFromTop).map { u256 in
            H256(from: u256.toBigEndian)
        }
    }

    /// Peeks a value at a given index from the top of the stack and converts it to `Int`.
    /// If the value is larger than `Int.max`, `ExitError.outOfGas` is returned.
    ///
    /// - Parameter indexFromTop: The index from the top of the stack.
    /// - Returns: A `Result` containing the `Int` value if successful, or an `ExitError` if an error occurs.
    func peek(indexFromTop: Int) -> Result<Int, Machine.ExitError> {
        switch peek(indexFromTop: indexFromTop) {
        case .success(let u256):
            U256.getMax
            let x = u256
            guard let intValue = u256.asUsable() else {
                return .failure(.OutOfGas)
            }
            return .success(intValue)
        case .failure(let error):
            return .failure(error)
        }
    }
}
