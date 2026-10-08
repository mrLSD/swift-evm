// NOTE: we're testing each opcode separately. And it includes be default
// each step of Machine eval loop.

import Foundation
@testable import Interpreter
import PrimitiveTypes

class TestHandler: InterpreterHandler {
    static let address1: H160 = try! .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5001").get()
    static let address2: H160 = try! .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5002").get()
    static let address3: H160 = try! .fromString(hex: "9A6402EEa6d967dBd7609346c11A1702Db4E5003").get()
    static let testGasPrice: U256 = .init(from: 123)
    var logs: [Log] = []

    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
        return nil
    }

    func balance(address: H160) -> U256 {
        switch address {
        case Self.address1:
            return U256(from: 5)
        case Self.address2:
            return U256(from: 10)
        default:
            return U256.ZERO
        }
    }

    func gasPrice() -> U256 {
        Self.testGasPrice
    }

    func origin() -> H160 {
        Self.address1
    }

    func chainId() -> U256 {
        U256(from: 33)
    }

    func coinbase() -> H160 {
        Self.address2
    }

    func isStatic() -> Bool {
        false
    }

    func log(address: H160, topics: [H256], data: [UInt8]) -> Result<Void, Machine.ExitError> {
        logs.append(Log(address: address, topics: topics, data: data))
        return .success(())
    }
}

enum TestMachine {
    static func defaultContext() -> Machine.Context {
        Machine.Context(targetAddress: H160.ZERO, callerAddress: H160.ZERO, callValue: U256.ZERO)
    }

    /// Init simple Machine
    static func machine(opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init simple Machine with Call Input Data
    static func machine(data: [UInt8], opcode: Opcode, gasLimit: UInt64) -> Machine {
        Machine(data: data, code: [opcode.rawValue], gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init Machine with Call Input Data and predefined code with array `Opcode` type and `memoryLimit`
    static func machine(data: [UInt8], opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: data, code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type
    static func machine(opcodes code: [Opcode], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: HardFork.latest())
    }

    /// Init Machine with predefined code with array `Opcode` type and `memoryLimit`, and hardFork
    static func machine(opcodes code: [Opcode], gasLimit: UInt64, memoryLimit: Int, hardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: memoryLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }

    /// Init Machine with predefined code with raw data
    static func machine(rawCode code: [UInt8], gasLimit: UInt64) -> Machine {
        Machine(data: [], code: code, gasLimit: gasLimit, context: defaultContext(), state: ExecutionState(), handler: TestHandler())
    }

    static func machineWithContext(opcode: Opcode, gasLimit: UInt64, context: Machine.Context) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, context: context, state: ExecutionState(), handler: TestHandler())
    }

    static func machine(opcode: Opcode, gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: [opcode.rawValue], gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }

    static func machine(opcodes code: [Opcode], gasLimit: UInt64, context: Machine.Context, hardFork: HardFork) -> Machine {
        Machine(data: [], code: code.map(\.rawValue), gasLimit: gasLimit, memoryLimit: 32000, context: context, state: ExecutionState(), handler: TestHandler(), hardFork: hardFork)
    }
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

#if TRACING
func captureStandardOutput(action: () -> Void) -> String {
    let pipe = Pipe()
    fflush(stdout)
    let original = dup(fileno(stdout))
    dup2(pipe.fileHandleForWriting.fileDescriptor, fileno(stdout))
    action()
    fflush(stdout)
    dup2(original, fileno(stdout))
    close(original)
    pipe.fileHandleForWriting.closeFile()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    pipe.fileHandleForReading.closeFile()
    return String(data: data, encoding: .utf8) ?? ""
}
#endif
