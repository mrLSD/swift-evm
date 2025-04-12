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

    init(machine: Machine, returnData: ReturnData, context: Context) {
        self.machine = machine
        self.returnData = returnData
        self.context = context
    }
}
