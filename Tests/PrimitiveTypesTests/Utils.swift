import Foundation

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
