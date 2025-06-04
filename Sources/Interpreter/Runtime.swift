import PrimitiveTypes

public final class Runtime {
    var machine: Machine

    init(code: [UInt8], data: [UInt8], gasLimit: UInt64, context: Machine.Context, handler: InterpreterHandler) {
        self.machine = Machine(data: data, code: code, gasLimit: 0, context: context, handler: handler)
    }
}
