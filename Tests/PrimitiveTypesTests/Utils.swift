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
    withStandardErrorRedirected(to: writeHandle) {
        action()
    }
    writeHandle.closeFile()
    let data = readHandle.readDataToEndOfFile()
    readHandle.closeFile()
    return String(data: data, encoding: .utf8) ?? ""
}
