import PrimitiveTypes

public final class Runtime {
    /// Runtime return data
    struct ReturnData {
        let buffer: [UInt8]
        let length: Int
        let offset: Int
    }

    /// Context of runtime
    struct Context {
        /// Execution target address
        let target: H160
        /// Sender (caller) address
        let sender: H160
        /// EVM apparent value
        let value: U256
    }

    var machine: Machine
    var returnData: ReturnData
    var context: Context

    init(code: [UInt8], data: [UInt8], gasLimit: UInt64, context: Context, handler: InterpreterHandler) {
        self.machine = Machine(data: data, code: code, gasLimit: 0, handler: handler)
        self.context = context
        self.returnData = ReturnData(buffer: [], length: 0, offset: 0)
    }
}
