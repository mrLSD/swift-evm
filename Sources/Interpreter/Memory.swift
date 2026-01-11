#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// Machine Memory with  specific limit.
public class Memory {
    /// Memory data
    private var buffer: UnsafeMutableRawPointer?

    /// Memory limit
    private(set) var limit: Int = 0

    /// Memory effective length, that changed after resize operations.
    private(set) var effectiveLength: Int = 0

    /// Creates a new memory instance that can be shared between calls.
    ///
    /// This initializer sets up a new instance with a specified memory limit.
    /// The `limit` parameter defines the maximum amount of memory that can be allocated for this instance.
    ///
    /// - Parameter limit: The upper bound for the memory size.
    init(limit: Int) {
        self.limit = limit
    }

    /// Creates a new memory instance that can be shared between calls.
    init() {
        self.limit = Int.max
    }

    /// Deinitializes the instance by freeing any allocated buffer memory.
    ///
    /// This deinitializer is automatically called when the instance is about to be deallocated.
    /// If a memory buffer has been allocated, its memory is released using `free(_:)` to prevent memory leaks.
    deinit {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        if let buf = buffer {
            free(buf)
        }
        #else
        buffer?.deallocate()
        #endif
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
    func resize(offset: Int, size: Int) -> Bool {
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
    func resize(end: Int) -> Bool {
        guard end > self.effectiveLength else {
            return true
        }

        let newSize = Memory.ceil32(end)
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        if let oldBuffer = self.buffer {
            guard let newBuffer = realloc(oldBuffer, newSize) else { return false }
            let offset = self.effectiveLength
            // Set resized `newSize` with zero
            Self.memSet(dstPtr: newBuffer.advanced(by: offset), value: 0, count: newSize - offset)
            self.buffer = newBuffer
        } else {
            guard let newBuffer = malloc(newSize) else { return false }
            Self.memSet(dstPtr: newBuffer, value: 0, count: newSize)
            self.buffer = newBuffer
        }
        #else
        let newBuffer: UnsafeMutableRawPointer
        let alignment = MemoryLayout<UInt8>.alignment

        if let oldBuffer = self.buffer {
            newBuffer = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: alignment)
            let offset = self.effectiveLength
            // Copy all memory from old to new buffer
            newBuffer.copyMemory(from: oldBuffer, byteCount: offset)
            // Fill newBuffer data with Zero after offset
            Self.memSet(dstPtr: newBuffer.advanced(by: offset), value: 0, count: newSize - offset)
            // We must deallocate old buffer to avoid memory leaks
            oldBuffer.deallocate()
        } else {
            newBuffer = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: alignment)
            Self.memSet(dstPtr: newBuffer, value: 0, count: newSize)
        }
        self.buffer = newBuffer
        #endif

        self.effectiveLength = newSize

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
    func get(offset: Int, size: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: size)
        guard size > 0, offset < self.effectiveLength, let buf = self.buffer else {
            return result
        }
        let copySize = size > self.effectiveLength - offset ? self.effectiveLength - offset : size

        // After all validation check we can guaranty that copySize is non zero
        result.withUnsafeMutableBytes { dest in
            Self.memCpy(dstPtr: dest.baseAddress!, srcPtr: buf.advanced(by: offset), count: copySize)
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
    func set(offset: Int, value: [UInt8], size: Int) -> Result<Void, Machine.ExitReason> {
        if size == 0 {
            return .success(())
        }

        if size > self.limit - offset {
            return .failure(.Error(.MemoryOperation(.SetLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = offset + size

        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        return value.withUnsafeBytes { src in
            // Get correct range for copy
            let copyCount = min(size, value.count)
            let dstPtr = buf.advanced(by: offset)
            let srcPtr = src.baseAddress!

            Self.memCpy(dstPtr: dstPtr, srcPtr: srcPtr, count: copyCount)

            if size > value.count {
                Self.memSet(dstPtr: buf.advanced(by: offset + value.count), value: 0, count: size - value.count)
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
    func copy(srcOffset: Int, dstOffset: Int, size: Int) -> Result<Void, Machine.ExitReason> {
        if size == 0 || srcOffset == dstOffset {
            return .success(())
        }

        let maxOffset = max(srcOffset, dstOffset)
        if size > self.limit - maxOffset {
            return .failure(.Error(.MemoryOperation(.CopyLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = maxOffset + size

        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        // SAFETY: We guaranty that buffer is not nil
        let srcPtr = buf.advanced(by: srcOffset)
        let dstPtr = buf.advanced(by: dstOffset)

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        // Correct copy for cross ranges with `memmove`
        memmove(dstPtr, srcPtr, size)
        #else
        let tempBuffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<UInt8>.alignment)
        tempBuffer.copyMemory(from: srcPtr, byteCount: size)
        dstPtr.copyMemory(from: tempBuffer, byteCount: size)
        tempBuffer.deallocate()
        #endif

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
    func copyData(memoryOffset: Int, dataOffset: Int, size: Int, data: [UInt8]) -> Result<Void, Machine.ExitReason> {
        // Check is no data to copy.
        if size == 0 {
            return .success(())
        }

        // Ensure the dataOffset is within bounds (allow dataOffset == data.count when size == 0 is already handled above).
        guard dataOffset >= 0, dataOffset < data.count else {
            return .failure(.Error(.MemoryOperation(.CopyDataOffsetOutOfBounds)))
        }

        // Calculate how many bytes are available starting from dataOffset.
        let available = data.count - dataOffset
        let copyLength = min(size, available)

        if size > self.limit - memoryOffset {
            return .failure(.Error(.MemoryOperation(.CopyDataLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = memoryOffset + size

        // Ensure the internal buffer is resized to accommodate the required length.
        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        guard let buf = self.buffer else { return .failure(.Fatal(.ReadMemory)) }

        return data.withUnsafeBytes { rawBuffer in
            // SAFETY: As we validated data length, we can unwrap `rawBuffer.baseAddress`
            let srcPtr = rawBuffer.baseAddress!.advanced(by: dataOffset)
            let dstPtr = buf.advanced(by: memoryOffset)
            Self.memCpy(dstPtr: dstPtr, srcPtr: srcPtr, count: copyLength)

            // If the requested length exceeds the available data, zero-fill the remainder.
            if size > copyLength {
                Self.memSet(dstPtr: dstPtr.advanced(by: copyLength), value: 0, count: size - copyLength)
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
    public static func ceil32(_ value: Int) -> Int {
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
    public static func numWords(_ value: Int) -> Int {
        let val = value.addingReportingOverflow(31)
        return (val.overflow ? Int.max : val.partialValue) >> 5
    }

    private static func memCpy(
        dstPtr: UnsafeMutableRawPointer,
        srcPtr: UnsafeRawPointer,
        count: Int
    ) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        memcpy(dstPtr, srcPtr, count)
        #else
        dstPtr.copyMemory(from: srcPtr, byteCount: count)
        #endif
    }

    @inline(__always)
    private static func memSet(dstPtr: UnsafeMutableRawPointer, value: UInt8, count: Int) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        memset(dstPtr, Int32(value), count)
        #else
        dstPtr.initializeMemory(as: UInt8.self, repeating: value, count: count)
        #endif
    }
}
