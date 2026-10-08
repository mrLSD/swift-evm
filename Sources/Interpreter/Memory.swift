import PrimitiveTypes

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// Machine memory bounded by `limit`: growth beyond it fails before any allocation.
/// Interpreter offsets and sizes are nonnegative. A positive effective length owns a buffer.
/// Opcodes expand and charge a range first and then use the `getWord`/`withUnsafeBytes`/`write*` accessors;
/// the `set`/`copy*` methods validate the limit and grow the buffer on their own.
public class Memory {
    /// Memory data
    private var buffer: UnsafeMutableRawPointer?

    /// Memory limit
    private(set) var limit: Int = 0

    /// Largest whole-word capacity that fits within the limit.
    var capacityLimit: Int { self.limit & ~31 }

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

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
    /// Allocation boundary; overrides must return malloc-compatible storage or nil.
    func allocateBuffer(byteCount: Int) -> UnsafeMutableRawPointer? {
        malloc(byteCount)
    }

    /// On failure, the existing allocation must remain valid and owned by Memory.
    func reallocateBuffer(_ buffer: UnsafeMutableRawPointer, byteCount: Int) -> UnsafeMutableRawPointer? {
        realloc(buffer, byteCount)
    }
    #endif

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

    /// Expands a nonempty range to a whole-word capacity within the memory limit.
    ///
    /// - Parameters:
    ///   - offset: Nonnegative starting byte offset.
    ///   - size: Nonnegative number of bytes in the range.
    /// - Returns: `false` for an empty range, overflow, a limit violation, or allocation failure.
    @inline(__always)
    final func resize(offset: Int, size: Int) -> Bool {
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
    /// - Returns: `true` if the buffer is already large enough or resizing succeeds; otherwise, `false` when
    ///            the rounded capacity overflows, exceeds `limit`, or allocation fails.
    /// - Note: This function is marked with `@inline(__always)` to suggest aggressive inlining for performance-critical contexts.
    @inline(__always)
    final func resize(end: Int) -> Bool {
        guard end > self.effectiveLength else {
            return true
        }
        // The limit bounds the allocation itself, for reads as well as writes.
        guard let newSize = Memory.ceil32(end), newSize <= self.limit else {
            return false
        }

        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        if let oldBuffer = self.buffer {
            guard let newBuffer = reallocateBuffer(oldBuffer, byteCount: newSize) else { return false }
            let offset = self.effectiveLength
            // Set resized `newSize` with zero
            Self.memSet(dstPtr: newBuffer.advanced(by: offset), value: 0, count: newSize - offset)
            self.buffer = newBuffer
        } else {
            guard let newBuffer = allocateBuffer(byteCount: newSize) else { return false }
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

    /// Reads a word from a range already expanded and charged by the interpreter.
    func getWord(offset: Int) -> U256 {
        precondition(offset >= 0 && offset <= self.effectiveLength - 32, "Word read requires 32 allocated bytes.")
        // The validated positive range guarantees a buffer.
        return U256(bigEndian: UnsafeRawBufferPointer(start: self.buffer!.advanced(by: offset), count: 32))
    }

    /// Exposes a nonempty range already expanded and charged by the interpreter without copying it.
    func withUnsafeBytes<R>(offset: Int, size: Int, _ body: (UnsafeRawBufferPointer) -> R) -> R {
        precondition(offset >= 0 && size > 0 && size <= self.effectiveLength - offset, "Byte read requires an allocated range.")
        // The validated positive range guarantees a buffer.
        return body(UnsafeRawBufferPointer(start: self.buffer!.advanced(by: offset), count: size))
    }

    /// Writes a word into a range already expanded and charged by the interpreter.
    func writeWord(offset: Int, _ value: U256) {
        precondition(offset >= 0 && offset <= self.effectiveLength - 32, "Word write requires 32 allocated bytes.")
        // The validated positive range guarantees a buffer.
        value.writeBigEndian(to: UnsafeMutableRawBufferPointer(start: self.buffer!.advanced(by: offset), count: 32))
    }

    /// Writes one byte into a range already expanded and charged by the interpreter.
    func writeByte(offset: Int, _ value: UInt8) {
        precondition(offset >= 0 && offset < self.effectiveLength, "Byte write requires an allocated byte.")
        // The validated positive range guarantees a buffer.
        self.buffer!.storeBytes(of: value, toByteOffset: offset, as: UInt8.self)
    }

    /// Copies `size` bytes of `data` from `dataOffset` into a range already expanded and charged by the
    /// interpreter, zero-filling whatever lies past the end of `data`.
    func writeData(offset: Int, size: Int, from data: [UInt8], dataOffset: Int) {
        precondition(offset >= 0 && size > 0 && size <= self.effectiveLength - offset, "Data write requires an allocated range.")
        precondition(dataOffset >= 0, "Data offsets must be nonnegative.")
        // The validated positive range guarantees a buffer.
        let dstPtr = self.buffer!.advanced(by: offset)

        let copyLength = dataOffset < data.count ? min(size, data.count - dataOffset) : 0
        if copyLength > 0 {
            // A positive copy length guarantees nonempty source data and a base address.
            data.withUnsafeBytes { Self.memCpy(dstPtr: dstPtr, srcPtr: $0.baseAddress!.advanced(by: dataOffset), count: copyLength) }
        }
        if size > copyLength {
            Self.memSet(dstPtr: dstPtr.advanced(by: copyLength), value: 0, count: size - copyLength)
        }
    }

    /// Stores a word with the same limit and allocation errors as byte-array writes.
    func set(offset: Int, word: U256) -> Result<Void, Machine.ExitReason> {
        precondition(offset >= 0, "Memory offsets must be nonnegative.")
        if self.capacityLimit - offset < 32 {
            return .failure(.Error(.MemoryOperation(.SetLimitExceeded)))
        }
        guard self.resize(end: offset + 32) else { return .failure(.Fatal(.ReadMemory)) }
        self.writeWord(offset: offset, word)

        return .success(())
    }

    /// Writes a byte range, growing memory within the limit and zero-filling any missing source bytes.
    ///
    /// - Parameters:
    ///   - offset: Nonnegative destination byte offset.
    ///   - value: Source bytes, truncated or zero-padded to `size`.
    ///   - size: Nonnegative number of bytes to write; zero leaves memory unchanged.
    /// - Returns: A limit error if the rounded capacity exceeds `limit`, or `.Fatal(.ReadMemory)` if allocation fails.
    @inline(__always)
    func set(offset: Int, value: [UInt8], size: Int) -> Result<Void, Machine.ExitReason> {
        if size == 0 {
            return .success(())
        }

        if size > self.capacityLimit - offset {
            return .failure(.Error(.MemoryOperation(.SetLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = offset + size

        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        self.writeData(offset: offset, size: size, from: value, dataOffset: 0)
        return .success(())
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
    /// executed using the C standard library function `memmove`, which safely handles overlapping memory regions.
    /// Allocation failure returns `.Fatal(.ReadMemory)` without changing the existing buffer.
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
        if size > self.capacityLimit - maxOffset {
            return .failure(.Error(.MemoryOperation(.CopyLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = maxOffset + size

        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        // Successful resize to a positive length guarantees an allocated buffer.
        let buf = self.buffer!

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

    /// Copies a source range into memory, zero-filling bytes beyond the end of `data`.
    ///
    /// - Parameters:
    ///   - memoryOffset: Nonnegative destination byte offset.
    ///   - dataOffset: Source byte offset; offsets beyond the source produce zeros.
    ///   - size: Nonnegative number of bytes to copy; zero leaves memory unchanged.
    ///   - data: Source bytes.
    /// - Returns: A specific memory error for a negative source offset or a limit violation,
    ///            or `.Fatal(.ReadMemory)` if allocation fails.
    @inline(__always)
    func copyData(memoryOffset: Int, dataOffset: Int, size: Int, data: [UInt8]) -> Result<Void, Machine.ExitReason> {
        // Check is no data to copy.
        if size == 0 {
            return .success(())
        }

        guard dataOffset >= 0 else {
            return .failure(.Error(.MemoryOperation(.CopyDataOffsetOutOfBounds)))
        }

        if size > self.capacityLimit - memoryOffset {
            return .failure(.Error(.MemoryOperation(.CopyDataLimitExceeded)))
        }
        // NOTE: after the above check, we can be sure that offset + size won't overflow
        let requiredLength = memoryOffset + size

        // Ensure the internal buffer is resized to accommodate the required length.
        guard self.resize(end: requiredLength) else { return .failure(.Fatal(.ReadMemory)) }
        self.writeData(offset: memoryOffset, size: size, from: data, dataOffset: dataOffset)

        return .success(())
    }

    /// Rounds a nonnegative byte count up to a multiple of 32, or returns `nil` if it exceeds `Int.max`.
    @inline(__always)
    public static func ceil32(_ value: Int) -> Int? {
        precondition(value >= 0, "Memory size must be nonnegative.")
        let val = value.addingReportingOverflow(31)
        return val.overflow ? nil : val.partialValue & ~31
    }

    /// Computes the exact number of 32-byte words needed for a nonnegative byte count without rounding overflow.
    @inline(__always)
    public static func numWords(_ value: Int) -> Int {
        precondition(value >= 0, "Memory size must be nonnegative.")
        return (value >> 5) + (value & 31 == 0 ? 0 : 1)
    }

    /// Copies `count` bytes from `srcPtr` to `dstPtr`.
    ///
    /// - Parameters:
    ///   - dstPtr: Destination memory address.
    ///   - srcPtr: Source memory address.
    ///   - count: Number of bytes to copy.
    /// - Note: Uses platform `memcpy` on Darwin/Glibc, otherwise falls back to `copyMemory(from:byteCount:)`.
    @inline(__always)
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

    /// Sets `count` bytes at `dstPtr` to `value`.
    ///
    /// - Parameters:
    ///   - dstPtr: Destination memory address.
    ///   - value: Byte value to write.
    ///   - count: Number of bytes to set.
    /// - Note: Uses platform `memset` on Darwin/Glibc, otherwise falls back to `initializeMemory(as:repeating:count:)`.
    @inline(__always)
    private static func memSet(dstPtr: UnsafeMutableRawPointer, value: UInt8, count: Int) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
        memset(dstPtr, Int32(value), count)
        #else
        dstPtr.initializeMemory(as: UInt8.self, repeating: value, count: count)
        #endif
    }
}
