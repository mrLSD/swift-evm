import Foundation
import PrimitiveTypes

func withStandardOutputRedirected(to writeStream: FileHandle, action: () -> Void) {
    let originalStdout = dup(fileno(stdout))
    dup2(writeStream.fileDescriptor, fileno(stdout))
    action()
    fflush(stdout)
    dup2(originalStdout, fileno(stdout))
    close(originalStdout)
}

func captureStandardOutput(action: () -> Void) -> String {
    let pipe = Pipe()
    let writeHandle = pipe.fileHandleForWriting
    let readHandle = pipe.fileHandleForReading

    defer { readHandle.closeFile() }

    do {
        defer { writeHandle.closeFile() }

        withStandardOutputRedirected(to: writeHandle) {
            action()
        }
    }

    let data = readHandle.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

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

func h160LastByte(_ b: UInt8) -> H160 {
    var bytes = [UInt8](repeating: 0, count: 20)
    bytes[19] = b
    return H160(from: bytes)
}

func h256LastByte(_ b: UInt8) -> H256 {
    var bytes = [UInt8](repeating: 0, count: 32)
    bytes[31] = b
    return H256(from: bytes)
}

func makeTempDirectory(prefix: String = "EthSpecTests") -> URL {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
}

func writeFixture(_ json: String, to url: URL) {
    try? json.data(using: .utf8)?.write(to: url)
}
