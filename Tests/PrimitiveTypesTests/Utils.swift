import Foundation
import Nimble

func withStandardErrorRedirected(to writeStream: FileHandle, action: () -> Void) {
    let originalStderr = dup(fileno(stderr))
    dup2(writeStream.fileDescriptor, fileno(stderr))
    action()
    fflush(stderr)
    dup2(originalStderr, fileno(stderr))
    close(originalStderr)
}

func captureStandardError(action: () -> Void) -> String {
    let pipe = Pipe()
    let writeHandle = pipe.fileHandleForWriting
    let readHandle = pipe.fileHandleForReading

    defer { readHandle.closeFile() }

    do {
        defer { writeHandle.closeFile() }

        withStandardErrorRedirected(to: writeHandle) {
            action()
        }
    }

    let data = readHandle.readDataToEndOfFile()

    return String(data: data, encoding: .utf8) ?? ""
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        // SplitMix64: https://prng.di.unimi.it/splitmix64.c
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private func divisionBytes(_ words: [UInt64]) -> [UInt8] {
    words.flatMap { word in
        (0 ..< 8).map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) }
    }
}

func expectDivisionIdentity(
    dividend: [UInt64], divisor: [UInt64], quotient: [UInt64], remainder: [UInt64], description: String,
    fileID: String = #fileID, file: FileString = #filePath, line: UInt = #line
) {
    let a = divisionBytes(dividend)
    let d = divisionBytes(divisor)
    let q = divisionBytes(quotient)
    let r = divisionBytes(remainder)

    // Reconstruct q*d+r in base 256 with twice the input width, without library arithmetic.
    var product = [UInt32](repeating: 0, count: a.count * 2 + 1)
    for i in q.indices {
        for j in d.indices {
            product[i + j] += UInt32(q[i]) * UInt32(d[j])
        }
    }

    for i in r.indices {
        product[i] += UInt32(r[i])
    }

    for i in 0 ..< product.count - 1 {
        product[i + 1] += product[i] >> 8
        product[i] &= 0xFF
    }
    let expected = a.map(UInt32.init) + [UInt32](repeating: 0, count: product.count - a.count)

    expect(fileID: fileID, file: file, line: line, product).to(equal(expected), description: description)
    expect(fileID: fileID, file: file, line: line, r.reversed().lexicographicallyPrecedes(d.reversed())).to(beTrue(), description: description)
}
