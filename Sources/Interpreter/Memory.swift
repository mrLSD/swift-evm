#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Machine Memory with  specific limit.
public class Memory {
    /// Memory data
    private var buffer: UnsafeMutableRawPointer?

    /// Memory limit
    private(set) var limit: UInt = 0

    /// Memory effective length, that changed after resize operations.
    private(set) var effectiveLength: UInt = 0

    /// Creates a new memory instance that can be shared between calls.
    ///
    /// This initializer sets up a new instance with a specified memory limit.
    /// The `limit` parameter defines the maximum amount of memory that can be allocated for this instance.
    ///
    /// - Parameter limit: The upper bound for the memory size.
    init(limit: UInt) {
        self.limit = limit
    }

    /// Creates a new memory instance that can be shared between calls.
    init() {
        self.limit = UInt(Int.max)
    }

    /// Deinitializes the instance by freeing any allocated buffer memory.
    ///
    /// This deinitializer is automatically called when the instance is about to be deallocated.
    /// If a memory buffer has been allocated, its memory is released using `free(_:)` to prevent memory leaks.
    deinit {
        if let buf = buffer {
            free(buf)
        }
    }

    /// Resizes the internal buffer to accommodate a range defined by a starting offset and a length.
    ///
    /// This method first checks if the provided `len` is non-zero. It then adds the `offset` and `len`
    /// while detecting potential arithmetic overflow. If an overflow occurs or if `len` is zero,
    /// the method returns `false`. Otherwise, it delegates the resizing operation to `resize(end:)`
    /// with the computed end offset.
    ///
    /// - Parameters:
    ///   - offset: The starting offset for the buffer.
    ///   - len: The length of the data to accommodate.
    /// - Returns: `true` if the buffer was successfully resized (or already has sufficient capacity),
    ///            `false` if the length is zero, an overflow occurred, or if resizing fails.
    /// - Note: This function is marked with `@inline(__always)` to encourage aggressive inlining in performance-critical contexts.
    @inline(__always)
    func resize(offset: UInt, size: UInt) -> Bool {
        if size == 0 {
            return false
        }

        let (end, overflow) = offset.addingReportingOverflow(size)
        guard !overflow else {
            return false
        }

        return self.resize(end: end)
    }

    /// Resizes the internal buffer so that it can accommodate data up to the specified offset.
    ///
    /// This method verifies whether the current buffer size (`effectiveLength`) is less than the desired `end` offset.
    /// If resizing is required, it calculates a new size rounded up to the nearest multiple of 32 (using `ceil32`), and then
    /// either resizes the existing buffer via `realloc` or allocates a new one using `malloc`. In the case of resizing, only
    /// the newly allocated memory is zero-initialized.
    ///
    /// - Parameter end: The minimum offset (or capacity) that the buffer must support.
    /// - Returns: `true` if the buffer is already large enough or if resizing succeeds; otherwise, `false` when memory allocation fails.
    /// - Note: This function is marked with `@inline(__always)` to suggest aggressive inlining for performance-critical contexts.
    @inline(__always)
    func resize(end: UInt) -> Bool {
        guard end > self.effectiveLength else {
            return true
        }
        let newSize = self.ceil32(Int(clamping: end))

        if let oldBuffer = self.buffer {
            guard let newBuffer = realloc(oldBuffer, newSize) else { return false }
            let offset = Int(self.effectiveLength)
            // Set resized `newSize` with zero
            memset(newBuffer.advanced(by: offset), 0, newSize - offset)
            self.buffer = newBuffer
        } else {
            guard let newBuffer = malloc(newSize) else { return false }
            memset(newBuffer, 0, newSize)
            self.buffer = newBuffer
        }

        self.effectiveLength = UInt(newSize)

        return true
    }

    /// Retrieves a segment of the Memory as an array of bytes.
    ///
    /// This method copies up to `size` bytes from the Memory starting at the specified `offset`.
    /// If the offset is beyond the Memory’s effective length, or if fewer than `size` bytes are available,
    /// the returned array is zero-padded to always have a length equal to `size`.
    ///
    /// - Parameters:
    ///   - offset: The starting offset within the Memory from which to copy bytes.
    ///   - size: The number of bytes to retrieve.
    /// - Returns: An array of `UInt8` with exactly `size` elements containing the data copied from the Memory,
    ///            with any missing bytes filled with zeros.
    /// - Note: The copy operation is safely bounded by the Memory's effective length.
    func get(offset: UInt, size: UInt) -> [UInt8] {
        // It's practically impossible value, we don't add additional checks for Int casting
        let intSize = Int(size)
        var result = [UInt8](repeating: 0, count: intSize)
        guard size > 0, offset < self.effectiveLength, let buf = self.buffer else {
            return result
        }
        let intOffset = Int(clamping: offset)

        // We don't check overflow, as it's practically impossible size for Memory
        let copySize = min(intOffset + intSize, Int(self.effectiveLength)) - intOffset

        // After all validation check we can guaranty that copySize is non zero
        _ = result.withUnsafeMutableBytes { dest in
            memcpy(dest.baseAddress, buf.advanced(by: intOffset), copySize)
        }
        return result
    }

    /// Sets a segment of the Memory with the provided byte values.
    ///
    /// This method writes a sequence of bytes into the Memory starting at the specified `offset`.
    /// The number of bytes to write is determined by the `size` parameter if provided; otherwise, it defaults to
    /// the length of the `value` array. If the provided `size` is greater than the length of `value`, the extra
    /// bytes are zero-filled.
    ///
    /// Before writing, the method verifies that the target range (from `offset` to `offset + targetSize`)
    /// does not exceed the Memory’s upper bound (`limit`). It then attempts to resize the Memory to accommodate
    /// the new data. If resizing fails or if the target range would exceed the allowed limit, the operation is aborted
    /// and the method returns `false`.
    ///
    /// - Parameters:
    ///   - offset: The starting offset in the Memory where the data should be written.
    ///   - value: An array of `UInt8` bytes that will be copied into the Memory.
    ///   - size: Number specifying how many bytes to write.
    /// - Returns: A `Result` containing the `Void` value if successful, or an `Machine.ExitReason` if an error occurs.
    /// - Note: If `size` is provided and is greater than the number of bytes in `value`, the extra bytes are filled with zeros.
    ///         This function is marked with `@inline(__always)` to promote aggressive inlining for performance-critical code paths.
    ///         It uses low-level memory operations (`memcpy` and `memset`), thereby bypassing some of Swift’s safety checks.
    @inline(__always)
    func set(offset: UInt, value: [UInt8], size: UInt) -> Result<Void, Machine.ExitReason> {
        if size == 0 {
            return .success(())
        }

        // We don't check type casting overflow, as it's impossible size for memory
        let intSize = Int(size)
        let intOffset = Int(offset)

        // We don't overflow as Int.max impossible size for memory
        let requiredLength = intOffset + intSize
        if requiredLength > self.limit {
            return .failure(.Error(.MemoryOperation(.SetLimitExceeded)))
        }

        guard self.resize(end: UInt(requiredLength)) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        return value.withUnsafeBytes { src in
            // Get correct range for copy
            let copyCount = min(intSize, value.count)
            memcpy(buf.advanced(by: intOffset), src.baseAddress, copyCount)

            if intSize > value.count {
                memset(buf.advanced(by: intOffset + value.count), 0, intSize - value.count)
            }

            return .success(())
        }
    }

    /// Copies a block of bytes within the Memory from one offset to another.
    ///
    /// This method copies `length` bytes of data from the source offset (`srcOffset`) to the destination offset (`dstOffset`)
    /// within the Memory. It first checks for trivial cases: if `length` is zero or if the source and destination offsets
    /// are identical, no copy is performed. It then calculates the required memory size by adding `length` to the maximum of
    /// the two offsets, ensuring that this value does not exceed the Memory's upper bound (`limit`). In case of an overflow
    /// or if the required length exceeds `limit`, the function returns a failure result with an appropriate error message.
    ///
    /// Before performing the copy, the Memory is resized to guarantee that the required range is available. The actual copy is
    /// executed using the C standard library function `memmove`, which safely handles overlapping memory regions. If either the
    /// resize operation fails or the internal buffer is unexpectedly `nil`, the function terminates via `fatalError`, reflecting
    /// that such conditions should never occur under normal operation.
    ///
    /// - Parameters:
    ///   - srcOffset: The starting offset from which bytes are to be copied.
    ///   - dstOffset: The starting offset where bytes are to be copied to.
    ///   - size: The number of bytes to copy.
    /// - Returns: A `Result` that is `.success(())` if the copy operation completes successfully,
    ///            or `.failure(Machine.ExitReason)` if the operation fails (for example, if the Memory limit is exceeded or an overflow occurs).
    /// - Note: This function is marked with `@inline(__always)` to promote aggressive inlining in performance-critical code paths.
    ///         It employs low-level memory operations directly (using `memmove`) instead of wrappers like `withUnsafeBytes` for maximum performance,
    ///         while ensuring safety through explicit bounds and overflow checks.
    @inline(__always)
    func copy(srcOffset: UInt, dstOffset: UInt, size: UInt) -> Result<Void, Machine.ExitReason> {
        if size == 0 || srcOffset == dstOffset {
            return .success(())
        }

        // We don't check type casting overflow, as it's impossible size for memory
        let intSrcOffset = Int(srcOffset)
        let intDstOffset = Int(dstOffset)
        let intSize = Int(size)

        let maxOffset = max(intSrcOffset, intDstOffset)
        // We don't check overflow as Int.max impossible size for memory
        let requiredLength = maxOffset + intSize
        if requiredLength > self.limit {
            return .failure(.Error(.MemoryOperation(.CopyLimitExceeded)))
        }

        guard self.resize(end: UInt(requiredLength)) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        // SAFTY: We guaranty that buffer is not nil
        let srcPtr = buf.advanced(by: intSrcOffset)
        let dstPtr = buf.advanced(by: intDstOffset)

        // Correct copy for cross ranges with `memmove`
        memmove(dstPtr, srcPtr, intSize)
        return .success(())
    }

    /// Copies a block of data from the provided byte array into the Memory buffer.
    ///
    /// This function performs an unsafe, high-performance copy of `len` bytes from the source `data` array,
    /// starting at the specified `dataOffset`, into the Memory buffer at the given `memoryOffset`.
    /// If the available data (from `dataOffset` to the end of the array) is less than `len` bytes,
    /// the remainder of the Memory region is zero-filled.
    ///
    /// - Parameters:
    ///   - memoryOffset: The offset in the Memory buffer where data will be written.
    ///   - dataOffset: The starting offset in the source `data` array from which to copy bytes.
    ///   - size: The number of bytes to copy. If the source data has fewer than `len` bytes after `dataOffset`,
    ///          the missing bytes will be filled with zeros.
    ///   - data: The source array of bytes from which the data is copied.
    ///
    /// - Returns: A `Result` indicating success, or a `Machine.ExitReason` if an error occurs (e.g., if the
    ///            `dataOffset` is out of bounds, memory limit is exceeded, or memory allocation/resizing fails).
    ///
    /// - Note: This function uses unsafe memory operations (`withUnsafeBytes`, `memcpy`, and `memset`) to achieve
    ///         maximum performance.
    @inline(__always)
    func copyData(memoryOffset: UInt, dataOffset: UInt, size: UInt, data: [UInt8]) -> Result<Void, Machine.ExitReason> {
        // Check is no data to copy.
        if size == 0 {
            return .success(())
        }

        // We don't check type casting overflow, as it's impossible size for memory
        let intDataOffset = Int(dataOffset)
        let intSize = Int(size)
        let intMemoryOffset = Int(memoryOffset)

        // Ensure the dataOffset is within bounds.
        guard intDataOffset < data.count else {
            return .failure(.Error(.MemoryOperation(.CopyDataOffsetOutOfBounds)))
        }

        // Calculate how many bytes are available starting from dataOffset.
        let available = data.count - intDataOffset
        let copyLength = min(intSize, available)

        // We don't check overflow as Int.max impossible size for memory
        let requiredLength = intMemoryOffset + intSize
        if requiredLength > self.limit {
            return .failure(.Error(.MemoryOperation(.CopyDataLimitExceeded)))
        }

        // Ensure the internal buffer is resized to accommodate the required length.
        guard self.resize(end: UInt(requiredLength)) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        return data.withUnsafeBytes { rawBuffer in
            // SAFTY: As we validated data length, we can unwrap `rawBuffer.baseAddress`
            let srcPtr = rawBuffer.baseAddress!.advanced(by: intDataOffset)
            let dstPtr = buf.advanced(by: intMemoryOffset)
            memcpy(dstPtr, srcPtr, copyLength)

            // If the requested length exceeds the available data, zero-fill the remainder.
            if intSize > copyLength {
                memset(dstPtr.advanced(by: copyLength), 0, intSize - copyLength)
            }
            return .success(())
        }
    }

    /// Converts a unsigned integer to the next closest multiple of 32.
    ///
    /// - Parameters:
    ///   - value: The value whose ceil32 is to be calculated.
    ///
    /// - Returns:
    ///   The same value if it's a perfect multiple of 32 else it returns the smallest multiple of 32 that is greater than `value`.
    @inline(__always)
    public func ceil32(_ value: Int) -> Int {
        let val = value.addingReportingOverflow(31)
        return (val.overflow ? Int.max : val.partialValue) & ~31
    }

    /// Computes the number of 32-byte words required to represent the given value.
    ///
    /// This function adds 31 to the provided `value` using arithmetic with overflow reporting
    /// and then divides the result by 32 (using a right shift by 5 bits). This effectively calculates
    /// the ceiling of `value / 32`. In case of an arithmetic overflow, it returns `UInt.max`.
    ///
    /// - Parameter value: The unsigned integer value to be converted into a count of 32-byte words.
    /// - Returns: The number of 32-byte words needed to represent `value`.
    @inline(__always)
    public func numWords(_ value: UInt) -> UInt {
        let val = value.addingReportingOverflow(31)
        return (val.overflow ? UInt.max : val.partialValue) >> 5
    }
}
