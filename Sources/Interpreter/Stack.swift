import PrimitiveTypes

/// EVM Machine Stack
struct Stack {
    public static let STACK_LIMIT: Int = 1024
    /// Stack data
    private var data: [U256] = []
    /// Stack limit
    let limit: Int
    /// Stack length
    var length: Int { self.data.count }

    /// Init Machine Stack with specific data limit
    init(limit: Int) {
        self.limit = limit
    }

    /// Init Machine Stack with default  stack limit
    init() {
        self.limit = Self.STACK_LIMIT
    }

    /// Push `U256` value to the Stack. Return error if it's reach limit.
    ///
    /// - Parameter value: `U256` value that will be pushed to Stacl
    /// - Returns: A `Result` containing the `VOid` value if successful, or an `ExitError.StackOverflow` if an error occurs.
    @inline(__always)
    mutating func push(value: U256) -> Result<Void, Machine.ExitError> {
        // Check stack overflow
        if self.data.count + 1 > self.limit {
            return .failure(.StackOverflow)
        }
        return .success(self.data.append(value))
    }

    /// Pop `U256` value from the Stack
    ///
    /// - Returns: A `Result` containing the `H256` value if successful, or an `ExitError.StackUnderflow` if stack is empty.
    @inline(__always)
    mutating func pop() -> Result<U256, Machine.ExitError> {
        guard let value = self.data.popLast() else {
            // Return error, if stack is empty
            return .failure(.StackUnderflow)
        }
        return .success(value)
    }

    /// Pop `H256` value from the Stack
    ///
    /// - Returns: A `Result` containing the `H256` value if successful, or an `ExitError.StackUnderflow` if stack is empty.
    @inline(__always)
    mutating func popH256() -> Result<H256, Machine.ExitError> {
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
    @inline(__always)
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
    @inline(__always)
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
    @inline(__always)
    func peekUInt(indexFromTop: Int) -> Result<UInt, Machine.ExitError> {
        switch self.peek(indexFromTop: indexFromTop) {
        case .success(let u256):
            guard let intValue = u256.getUInt else {
                return .failure(.OutOfGas)
            }
            return .success(intValue)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Sets a value at the specified index from the top of the stack.
    ///
    /// The top of the stack is considered at index `0`. If the provided index is out of bounds,
    /// the function returns a failure with `ExitError.stackUnderflow`.
    ///
    /// - Parameters:
    ///   - indexFromTop: The zero-based index from the top of the stack.
    ///   - value: The `U256` value to set at the specified index.
    /// - Returns: A `Result` indicating success (`Void`) or failure (`ExitError`).
    @inline(__always)
    mutating func set(indexFromTop: Int, value: U256) -> Result<Void, Machine.ExitError> {
        if self.data.count > indexFromTop, indexFromTop >= 0 {
            let index = self.data.count - indexFromTop - 1
            self.data[index] = value
            return .success(())
        } else {
            return .failure(.StackUnderflow)
        }
    }
}
